import assert from 'node:assert/strict';
import { mkdtemp, chmod, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, before, test } from 'node:test';
import { startAccessGateway } from './auth-gateway.mjs';

const PUBLIC_ORIGIN = 'https://test.popi.invalid';
const USERNAME = 'popi';
const PASSWORD = 'correct horse battery staple';
let nowMs = Date.UTC(2026, 9, 24, 8, 0, 0);
let gateway;
let baseUrl;
let testRoot;
let configPath;

before(async () => {
  testRoot = await mkdtemp(join(tmpdir(), 'popi-access-test-'));
  configPath = join(testRoot, 'access.json');
  await writeFile(configPath, JSON.stringify({
    username: USERNAME,
    password: PASSWORD,
    sessionSecret: 'test-only-session-secret-that-is-at-least-32-bytes',
  }), { mode: 0o600 });
  await chmod(configPath, 0o600);
  gateway = await startAccessGateway({
    configPath,
    origin: PUBLIC_ORIGIN,
    port: 0,
    now: () => nowMs,
    sessionTtlMs: 60_000,
  });
  baseUrl = `http://127.0.0.1:${gateway.port}`;
});

after(async () => {
  await gateway?.close();
  await rm(testRoot, { recursive: true, force: true });
});

async function login(password = PASSWORD, extra = {}) {
  return fetch(`${baseUrl}/login`, {
    method: 'POST',
    redirect: 'manual',
    headers: {
      Origin: PUBLIC_ORIGIN,
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Forwarded-For': extra.ip ?? '203.0.113.10',
      ...extra.headers,
    },
    body: new URLSearchParams({ username: USERNAME, password }),
  });
}

function sessionCookie(response) {
  const setCookie = response.headers.get('set-cookie');
  assert.ok(setCookie);
  return setCookie.split(';', 1)[0];
}

test('serves login form without exposing credentials', async () => {
  const response = await fetch(`${baseUrl}/login`);
  const body = await response.text();
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('referrer-policy'), 'same-origin');
  assert.match(response.headers.get('content-security-policy'), /script-src 'self'/);
  assert.match(body, /<form action="\/login" method="post">/);
  assert.match(body, /name="username"[^>]*autocorrect="off"[^>]*autocapitalize="none"[^>]*spellcheck="false"/);
  assert.match(body, /name="password"[^>]*autocorrect="off"[^>]*autocapitalize="none"[^>]*spellcheck="false"/);
  assert.match(body, /type="button"[^>]*aria-controls="password"[^>]*aria-pressed="false"[^>]*aria-label="显示密码"/);
  assert.match(body, /密码区分大小写，不含空格。/);
  assert.match(body, /<script src="\/login\.js" defer><\/script>/);
  assert.doesNotMatch(body, /onclick=/);
  assert.doesNotMatch(body, new RegExp(PASSWORD));

  const script = await fetch(`${baseUrl}/login.js`);
  const source = await script.text();
  assert.equal(script.status, 200);
  assert.equal(script.headers.get('cache-control'), 'no-store');
  assert.match(script.headers.get('content-type'), /^text\/javascript/);
  assert.match(source, /addEventListener\('click'/);
  assert.match(source, /aria-pressed/);
});

test('unauthenticated page redirects and API receives JSON 401', async () => {
  const page = await fetch(`${baseUrl}/verify`, {
    redirect: 'manual',
    headers: { 'X-Forwarded-Uri': '/assets/main.dart.js' },
  });
  assert.equal(page.status, 302);
  assert.equal(page.headers.get('location'), '/login');

  const api = await fetch(`${baseUrl}/verify`, {
    redirect: 'manual',
    headers: { 'X-Forwarded-Uri': '/api_agent/conversations' },
  });
  assert.equal(api.status, 401);
  assert.deepEqual(await api.json(), { error: 'authentication_required' });
});

test('successful login issues hardened cookie and verifies it', async () => {
  const response = await login();
  assert.equal(response.status, 303);
  assert.equal(response.headers.get('location'), '/');
  const setCookie = response.headers.get('set-cookie');
  assert.match(setCookie, /^__Host-popi-test=/);
  assert.match(setCookie, /; Path=\/; HttpOnly; Secure; SameSite=Strict$/);
  assert.doesNotMatch(setCookie, new RegExp(PASSWORD));

  const verify = await fetch(`${baseUrl}/verify`, {
    headers: {
      Cookie: sessionCookie(response),
      'X-Forwarded-Uri': '/',
    },
  });
  assert.equal(verify.status, 204);
  assert.equal(await verify.text(), '');
});

test('wrong password receives only generic failure', async () => {
  const response = await login('wrong password', { ip: '203.0.113.11' });
  assert.equal(response.status, 303);
  assert.equal(response.headers.get('location'), '/login?error=invalid');
  assert.equal(response.headers.get('set-cookie'), null);
});

test('blocked login returns 429, preserves its window, and expires on schedule', async () => {
  const ip = '203.0.113.16';
  const startedAt = nowMs;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const response = await login(`wrong-${attempt}`, { ip });
    assert.equal(response.status, 303);
    assert.equal(response.headers.get('location'), '/login?error=invalid');
  }
  try {
    const blockedCorrectPassword = await login(PASSWORD, { ip });
    assert.equal(blockedCorrectPassword.status, 429);
    assert.equal(blockedCorrectPassword.headers.get('retry-after'), '900');
    assert.equal(blockedCorrectPassword.headers.get('set-cookie'), null);
    assert.match(await blockedCorrectPassword.text(), /尝试次数过多，请在 15 分钟后重试。/);

    nowMs += 5 * 60_000;
    const stillBlocked = await login(PASSWORD, { ip });
    assert.equal(stillBlocked.status, 429);
    assert.equal(stillBlocked.headers.get('retry-after'), '600');
    assert.match(await stillBlocked.text(), /尝试次数过多，请在 10 分钟后重试。/);

    nowMs += 10 * 60_000;
    const afterWindow = await login(PASSWORD, { ip });
    assert.equal(afterWindow.status, 303);
    assert.equal(afterWindow.headers.get('location'), '/');
    assert.match(afterWindow.headers.get('set-cookie'), /^__Host-popi-test=/);
  } finally {
    nowMs = startedAt;
  }
});

test('rate limiting is isolated by client IP', async () => {
  const blockedIp = '203.0.113.17';
  for (let attempt = 0; attempt < 5; attempt += 1) {
    await login(`wrong-${attempt}`, { ip: blockedIp });
  }
  const blocked = await login(PASSWORD, { ip: blockedIp });
  assert.equal(blocked.status, 429);

  const otherClient = await login(PASSWORD, { ip: '203.0.113.18' });
  assert.equal(otherClient.status, 303);
  assert.equal(otherClient.headers.get('location'), '/');
  assert.match(otherClient.headers.get('set-cookie'), /^__Host-popi-test=/);
});

test('successful login clears prior failures for that IP', async () => {
  const ip = '203.0.113.19';
  for (let attempt = 0; attempt < 4; attempt += 1) {
    await login(`wrong-before-${attempt}`, { ip });
  }
  assert.equal((await login(PASSWORD, { ip })).status, 303);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    await login(`wrong-after-${attempt}`, { ip });
  }
  const secondSuccess = await login(PASSWORD, { ip });
  assert.equal(secondSuccess.status, 303);
  assert.match(secondSuccess.headers.get('set-cookie'), /^__Host-popi-test=/);
});

test('password comparison preserves case and whitespace exactly', async () => {
  const variants = [
    ` ${PASSWORD}`,
    `${PASSWORD} `,
    PASSWORD.toUpperCase(),
  ];
  for (const [index, variant] of variants.entries()) {
    const response = await login(variant, { ip: `203.0.113.${30 + index}` });
    assert.equal(response.status, 303);
    assert.equal(response.headers.get('location'), '/login?error=invalid');
    assert.equal(response.headers.get('set-cookie'), null);
  }
});

test('failure limiter evicts its oldest entry when capacity is reached', async () => {
  const limitedGateway = await startAccessGateway({
    configPath,
    origin: PUBLIC_ORIGIN,
    port: 0,
    now: () => nowMs,
    failureCapacity: 3,
  });
  const limitedBaseUrl = `http://127.0.0.1:${limitedGateway.port}`;
  const limitedLogin = (password, ip) => fetch(`${limitedBaseUrl}/login`, {
    method: 'POST',
    redirect: 'manual',
    headers: {
      Origin: PUBLIC_ORIGIN,
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Forwarded-For': ip,
    },
    body: new URLSearchParams({ username: USERNAME, password }),
  });

  try {
    const oldestIp = '198.51.100.1';
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await limitedLogin(`wrong-${attempt}`, oldestIp);
    }
    const stillBlocked = await limitedLogin(PASSWORD, oldestIp);
    assert.equal(stillBlocked.status, 429);
    assert.equal(stillBlocked.headers.get('set-cookie'), null);

    await limitedLogin('wrong', '198.51.100.2');
    await limitedLogin('wrong', '198.51.100.3');
    await limitedLogin('wrong', '198.51.100.4');

    const afterEviction = await limitedLogin(PASSWORD, oldestIp);
    assert.equal(afterEviction.status, 303);
    assert.equal(afterEviction.headers.get('location'), '/');
    assert.match(afterEviction.headers.get('set-cookie'), /^__Host-popi-test=/);
  } finally {
    await limitedGateway.close();
  }
});

test('tampered signature is rejected', async () => {
  const response = await login(PASSWORD, { ip: '203.0.113.12' });
  const cookie = sessionCookie(response);
  const last = cookie.at(-1);
  const tampered = `${cookie.slice(0, -1)}${last === 'A' ? 'B' : 'A'}`;
  const verify = await fetch(`${baseUrl}/verify`, {
    redirect: 'manual',
    headers: { Cookie: tampered, 'X-Forwarded-Uri': '/' },
  });
  assert.equal(verify.status, 302);
  assert.equal(verify.headers.get('location'), '/login');
});

test('expired session is rejected', async () => {
  const response = await login(PASSWORD, { ip: '203.0.113.13' });
  const cookie = sessionCookie(response);
  nowMs += 60_001;
  try {
    const verify = await fetch(`${baseUrl}/verify`, {
      redirect: 'manual',
      headers: { Cookie: cookie, 'X-Forwarded-Uri': '/' },
    });
    assert.equal(verify.status, 302);
    assert.equal(verify.headers.get('location'), '/login');
  } finally {
    nowMs -= 60_001;
  }
});

test('cross-origin login is rejected', async () => {
  const response = await login(PASSWORD, {
    ip: '203.0.113.14',
    headers: { Origin: 'https://attacker.invalid' },
  });
  assert.equal(response.status, 403);
  assert.equal(response.headers.get('set-cookie'), null);
});

test('oversized login body is rejected', async () => {
  const response = await fetch(`${baseUrl}/login`, {
    method: 'POST',
    redirect: 'manual',
    headers: {
      Origin: PUBLIC_ORIGIN,
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Forwarded-For': '203.0.113.15',
    },
    body: `username=${USERNAME}&password=${'x'.repeat(5000)}`,
  });
  assert.equal(response.status, 413);
  assert.equal(response.headers.get('set-cookie'), null);
});

test('same-origin logout clears the session cookie', async () => {
  const response = await fetch(`${baseUrl}/logout`, {
    method: 'POST',
    redirect: 'manual',
    headers: { Origin: PUBLIC_ORIGIN },
  });
  assert.equal(response.status, 303);
  assert.equal(response.headers.get('location'), '/login');
  assert.match(response.headers.get('set-cookie'), /^__Host-popi-test=; Max-Age=0;/);
});
