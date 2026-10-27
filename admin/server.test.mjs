import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { startAdminServer } from './server.mjs';

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return server.address().port;
}

async function close(server) {
  server.closeAllConnections?.();
  await new Promise((resolve) => server.close(resolve));
}

async function makeFixture(t, upstreamHandler) {
  const upstream = http.createServer(upstreamHandler);
  const upstreamPort = await listen(upstream);
  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'popi-admin-'));
  const staticDir = path.join(tempDir, 'public');
  await mkdir(staticDir);
  await writeFile(path.join(staticDir, 'index.html'), '<!doctype html><title>POPi Admin</title>');
  await writeFile(path.join(staticDir, 'app.js'), 'globalThis.POPI_ADMIN = true;');
  await writeFile(path.join(staticDir, 'model.mjs'), 'export const state = {};');
  const configPath = path.join(tempDir, 'test.json');
  await writeFile(configPath, JSON.stringify({
    AGENT_API_BASE_URL: `http://127.0.0.1:${upstreamPort}`,
    AGENT_API_ORIGIN: 'http://127.0.0.1:7357',
  }));
  const admin = await startAdminServer({ port: 0, environment: configPath, staticDir });

  t.after(async () => {
    await close(admin.server);
    await close(upstream);
    await rm(tempDir, { recursive: true, force: true });
  });
  return { ...admin, upstreamPort };
}

test('serves static files, public config, and proxied health with security headers', async (t) => {
  const fixture = await makeFixture(t, (request, response) => {
    assert.equal(request.url, '/health');
    response.setHeader('Content-Type', 'application/json');
    response.end('{"ok":true}');
  });

  const indexResponse = await fetch(`${fixture.url}/`);
  assert.equal(indexResponse.status, 200);
  assert.match(await indexResponse.text(), /POPi Admin/);
  assert.equal(indexResponse.headers.get('cache-control'), 'no-store');
  assert.equal(indexResponse.headers.get('x-content-type-options'), 'nosniff');
  assert.match(indexResponse.headers.get('content-security-policy'), /script-src 'self'/);

  const moduleResponse = await fetch(`${fixture.url}/model.mjs`);
  assert.equal(moduleResponse.status, 200);
  assert.equal(moduleResponse.headers.get('content-type'), 'text/javascript; charset=utf-8');

  const configResponse = await fetch(`${fixture.url}/admin-config`);
  assert.deepEqual(await configResponse.json(), {
    environment: 'test',
    agentBaseUrl: `http://127.0.0.1:${fixture.upstreamPort}`,
  });

  const healthResponse = await fetch(`${fixture.url}/health`);
  assert.equal(healthResponse.status, 200);
  assert.deepEqual(await healthResponse.json(), { ok: true });
});

test('returns a Chinese JSON error when the Agent service is offline', async (t) => {
  const unavailable = http.createServer();
  const unavailablePort = await listen(unavailable);
  await close(unavailable);

  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'popi-admin-offline-'));
  const configPath = path.join(tempDir, 'offline.json');
  await writeFile(configPath, JSON.stringify({
    AGENT_API_BASE_URL: `http://127.0.0.1:${unavailablePort}`,
    AGENT_API_ORIGIN: 'http://127.0.0.1:7357',
  }));
  const admin = await startAdminServer({ port: 0, environment: configPath, staticDir: tempDir });
  t.after(async () => {
    await close(admin.server);
    await rm(tempDir, { recursive: true, force: true });
  });

  const response = await fetch(`${admin.url}/health`);
  assert.equal(response.status, 502);
  const payload = await response.json();
  assert.equal(payload.error.code, 'UPSTREAM_UNAVAILABLE');
  assert.match(payload.error.message, /Agent 服务/);
});

test('rejects unknown APIs, disallowed queries, spoofed origins, and remote configuration', async (t) => {
  const fixture = await makeFixture(t, (_request, response) => response.end('{}'));

  assert.equal((await fetch(`${fixture.url}/api_agent/v2/unknown`)).status, 404);
  assert.equal((await fetch(`${fixture.url}/api_agent/v2/sessions?token=secret`)).status, 405);
  const crossOrigin = await fetch(`${fixture.url}/api_agent/v2/sessions/11111111-1111-1111-1111-111111111111`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Origin: 'http://evil.example' },
    body: JSON.stringify({ title: 'blocked' }),
  });
  assert.equal(crossOrigin.status, 403);

  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'popi-admin-remote-'));
  const configPath = path.join(tempDir, 'remote.json');
  await writeFile(configPath, JSON.stringify({
    AGENT_API_BASE_URL: 'https://example.com',
    AGENT_API_ORIGIN: 'http://127.0.0.1:7357',
  }));
  t.after(() => rm(tempDir, { recursive: true, force: true }));
  await assert.rejects(startAdminServer({ port: 0, environment: configPath }), /本机 HTTP 地址/);
});

test('forwards only approved PATCH and stop fields without browser credentials', async (t) => {
  const received = [];
  const fixture = await makeFixture(t, async (request, response) => {
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    received.push({
      method: request.method,
      url: request.url,
      body: JSON.parse(Buffer.concat(chunks).toString()),
      origin: request.headers.origin,
      cookie: request.headers.cookie,
      authorization: request.headers.authorization,
    });
    response.setHeader('Content-Type', 'application/json');
    response.end('{"accepted":true}');
  });
  const sessionId = '22222222-2222-2222-2222-222222222222';
  const headers = {
    'Content-Type': 'application/json',
    Origin: fixture.url,
    Cookie: 'session=private',
    Authorization: 'Bearer private',
  };

  const patchResponse = await fetch(`${fixture.url}/api_agent/v2/sessions/${sessionId}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ clientRequestId: 'patch-1', title: '本机测试', pinned: true }),
  });
  assert.equal(patchResponse.status, 200);

  const stopResponse = await fetch(`${fixture.url}/api_agent/v2/sessions/${sessionId}/stop`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ clientRequestId: 'stop-1' }),
  });
  assert.equal(stopResponse.status, 200);
  assert.deepEqual(received.map(({ method, url, body }) => ({ method, url, body })), [
    {
      method: 'PATCH',
      url: `/api_agent/v2/sessions/${sessionId}`,
      body: { clientRequestId: 'patch-1', title: '本机测试', pinned: true },
    },
    {
      method: 'POST',
      url: `/api_agent/v2/sessions/${sessionId}/stop`,
      body: { clientRequestId: 'stop-1' },
    },
  ]);
  for (const request of received) {
    assert.equal(request.origin, 'http://127.0.0.1:7357');
    assert.equal(request.cookie, undefined);
    assert.equal(request.authorization, undefined);
  }

  const rejected = await fetch(`${fixture.url}/api_agent/v2/sessions/${sessionId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Origin: fixture.url },
    body: JSON.stringify({ title: 'bad', token: 'must-not-pass' }),
  });
  assert.equal(rejected.status, 400);
  assert.equal(received.length, 2);

  const invalidBodies = [
    { title: 'missing request id' },
    { clientRequestId: '   ', title: 'blank request id' },
    { clientRequestId: 'x'.repeat(129), title: 'long request id' },
    { clientRequestId: 'patch-empty-title', title: '   ' },
    { clientRequestId: 'patch-long-title', title: 'x'.repeat(121) },
  ];
  for (const invalidBody of invalidBodies) {
    const response = await fetch(`${fixture.url}/api_agent/v2/sessions/${sessionId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Origin: fixture.url },
      body: JSON.stringify(invalidBody),
    });
    assert.equal(response.status, 400);
  }
  assert.equal(received.length, 2);
});

test('streams Range responses and forwards HEAD without buffering credentials', async (t) => {
  const methods = [];
  const fixture = await makeFixture(t, (request, response) => {
    methods.push({ method: request.method, range: request.headers.range });
    response.setHeader('Accept-Ranges', 'bytes');
    response.setHeader('Content-Type', 'video/mp4');
    if (request.method === 'HEAD') {
      response.setHeader('Content-Length', '10');
      response.end();
      return;
    }
    assert.equal(request.headers.range, 'bytes=2-5');
    response.statusCode = 206;
    response.setHeader('Content-Range', 'bytes 2-5/10');
    response.end('2345');
  });
  const assetId = '33333333-3333-3333-3333-333333333333';
  const target = `${fixture.url}/api_agent/v2/assets/${assetId}/content`;

  const ranged = await fetch(target, { headers: { Range: 'bytes=2-5' } });
  assert.equal(ranged.status, 206);
  assert.equal(ranged.headers.get('content-range'), 'bytes 2-5/10');
  assert.equal(await ranged.text(), '2345');

  const head = await fetch(target, { method: 'HEAD' });
  assert.equal(head.status, 200);
  assert.equal(head.headers.get('content-length'), '10');
  assert.equal(await head.text(), '');
  assert.deepEqual(methods, [
    { method: 'GET', range: 'bytes=2-5' },
    { method: 'HEAD', range: undefined },
  ]);
});
