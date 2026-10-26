import { createHmac, createHash, timingSafeEqual } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_CONFIG_PATH = '/etc/popi-access/access.json';
const DEFAULT_LOGIN_HTML_PATH = resolve(
  dirname(fileURLToPath(import.meta.url)),
  'login.html',
);
const DEFAULT_LOGIN_JS_PATH = resolve(
  dirname(fileURLToPath(import.meta.url)),
  'login.js',
);
const MAX_CONFIG_BYTES = 16 * 1024;
const MAX_FORM_BYTES = 4 * 1024;
const SESSION_TTL_MS = 24 * 60 * 60 * 1000;
const COOKIE_NAME = '__Host-popi-test';
const FAILURE_WINDOW_MS = 15 * 60 * 1000;
const FAILURE_LIMIT = 5;
const FAILURE_CAPACITY = 1024;

function assertCleanHttpsOrigin(value) {
  if (!value) throw new Error('POPI_ACCESS_ORIGIN is required.');
  const parsed = new URL(value);
  if (
    parsed.protocol !== 'https:' ||
    parsed.origin !== value ||
    parsed.username ||
    parsed.password ||
    parsed.pathname !== '/' ||
    parsed.search ||
    parsed.hash
  ) {
    throw new Error('POPI_ACCESS_ORIGIN must be a clean HTTPS origin.');
  }
  return parsed.origin;
}

async function loadConfig(configPath) {
  const info = await stat(configPath);
  if (!info.isFile() || (info.mode & 0o077) !== 0) {
    throw new Error('Access config must be a private regular file.');
  }
  if (info.size > MAX_CONFIG_BYTES) {
    throw new Error('Access config is too large.');
  }
  const raw = await readFile(configPath, 'utf8');
  let value;
  try {
    value = JSON.parse(raw);
  } catch {
    throw new Error('Access config is not valid JSON.');
  }
  if (
    !value ||
    typeof value !== 'object' ||
    typeof value.username !== 'string' ||
    value.username.length < 1 ||
    value.username.length > 128 ||
    typeof value.password !== 'string' ||
    value.password.length < 1 ||
    value.password.length > 1024 ||
    typeof value.sessionSecret !== 'string' ||
    Buffer.byteLength(value.sessionSecret, 'utf8') < 32
  ) {
    throw new Error('Access config fields are invalid.');
  }
  return Object.freeze({
    username: value.username,
    password: value.password,
    sessionSecret: value.sessionSecret,
  });
}

function digestCredential(username, password) {
  const hash = createHash('sha256');
  hash.update(String(Buffer.byteLength(username, 'utf8')));
  hash.update(':');
  hash.update(username);
  hash.update(':');
  hash.update(password);
  return hash.digest();
}

function safeEqual(left, right) {
  return left.length === right.length && timingSafeEqual(left, right);
}

function signPayload(payload, secret) {
  return createHmac('sha256', secret).update(payload).digest('base64url');
}

function createSessionValue(username, expiresAt, secret) {
  const payload = Buffer.from(
    JSON.stringify({ username, expiresAt }),
    'utf8',
  ).toString('base64url');
  return `${payload}.${signPayload(payload, secret)}`;
}

function verifySessionValue(value, config, now) {
  if (typeof value !== 'string' || value.length > 4096) return false;
  const separator = value.indexOf('.');
  if (separator < 1 || separator !== value.lastIndexOf('.')) return false;
  const payload = value.slice(0, separator);
  const signature = value.slice(separator + 1);
  const expected = signPayload(payload, config.sessionSecret);
  if (!safeEqual(Buffer.from(signature), Buffer.from(expected))) return false;

  let session;
  try {
    session = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch {
    return false;
  }
  return (
    session &&
    session.username === config.username &&
    Number.isSafeInteger(session.expiresAt) &&
    session.expiresAt > now()
  );
}

function cookieValue(request, name) {
  const cookie = request.headers.cookie;
  if (typeof cookie !== 'string' || cookie.length > 8192) return undefined;
  for (const segment of cookie.split(';')) {
    const trimmed = segment.trim();
    const separator = trimmed.indexOf('=');
    if (separator > 0 && trimmed.slice(0, separator) === name) {
      return trimmed.slice(separator + 1);
    }
  }
  return undefined;
}

function securityHeaders(contentType) {
  return {
    'Cache-Control': 'no-store',
    'Content-Type': contentType,
    // Form navigations need a same-origin Origin for the CSRF check below.
    'Referrer-Policy': 'same-origin',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
  };
}

function send(response, status, body, contentType = 'text/plain; charset=utf-8', extra = {}) {
  response.writeHead(status, {
    ...securityHeaders(contentType),
    'Content-Length': Buffer.byteLength(body),
    ...extra,
  });
  response.end(body);
}

function redirect(response, location, extra = {}, status = 303) {
  send(response, status, '', 'text/plain; charset=utf-8', {
    Location: location,
    ...extra,
  });
}

function parseForwardedUri(request) {
  const value = request.headers['x-forwarded-uri'];
  if (typeof value !== 'string' || value.length > 8192 || !value.startsWith('/')) {
    return '/';
  }
  return value;
}

function isApiUri(uri) {
  return uri === '/api_agent' || uri.startsWith('/api_agent/');
}

function clientKey(request) {
  const forwarded = request.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length <= 256) {
    const first = forwarded.split(',', 1)[0].trim();
    if (/^[0-9a-fA-F:.]{3,64}$/.test(first)) return first;
  }
  return request.socket.remoteAddress ?? 'loopback';
}

function createFailureLimiter(now, capacity) {
  const failures = new Map();
  const discardExpired = (time) => {
    for (const [candidate, value] of failures) {
      if (time - value.startedAt >= FAILURE_WINDOW_MS) failures.delete(candidate);
    }
  };
  return {
    retryAfterMs(key) {
      const entry = failures.get(key);
      if (!entry) return 0;
      const remaining = FAILURE_WINDOW_MS - (now() - entry.startedAt);
      if (remaining <= 0) {
        failures.delete(key);
        return 0;
      }
      return entry.count >= FAILURE_LIMIT ? remaining : 0;
    },
    fail(key) {
      const time = now();
      const entry = failures.get(key);
      if (!entry || time - entry.startedAt >= FAILURE_WINDOW_MS) {
        if (!entry && failures.size >= capacity) {
          discardExpired(time);
          while (failures.size >= capacity) {
            const oldest = failures.keys().next().value;
            if (oldest === undefined) break;
            failures.delete(oldest);
          }
        }
        failures.set(key, { count: 1, startedAt: time });
      } else {
        entry.count += 1;
      }
    },
    clear(key) {
      failures.delete(key);
    },
  };
}

function readBoundedBody(request, limit = MAX_FORM_BYTES) {
  return new Promise((resolveBody) => {
    let size = 0;
    const chunks = [];
    let settled = false;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolveBody(result);
    };
    const timer = setTimeout(() => {
      request.resume();
      finish({ error: 'timeout' });
    }, 10_000);
    request.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        request.resume();
        finish({ error: 'too-large' });
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => finish({ body: Buffer.concat(chunks).toString('utf8') }));
    request.on('aborted', () => finish({ error: 'aborted' }));
    request.on('error', () => finish({ error: 'invalid' }));
  });
}

function renderLogin(template, message = '') {
  return template.replace(
    '{{ERROR_MESSAGE}}',
    message,
  );
}

function invalidLoginMessage() {
  return '<p class="error" role="alert">用户名或密码不正确，请重试。</p>';
}

function blockedLoginMessage(retryAfterMs) {
  const minutes = Math.max(1, Math.ceil(retryAfterMs / 60_000));
  return `<p class="error" role="alert">尝试次数过多，请在 ${minutes} 分钟后重试。</p>`;
}

export async function startAccessGateway({
  configPath = DEFAULT_CONFIG_PATH,
  loginHtmlPath = DEFAULT_LOGIN_HTML_PATH,
  loginJsPath = DEFAULT_LOGIN_JS_PATH,
  origin = process.env.POPI_ACCESS_ORIGIN,
  host = '127.0.0.1',
  port = 3085,
  now = Date.now,
  sessionTtlMs = SESSION_TTL_MS,
  failureCapacity = FAILURE_CAPACITY,
} = {}) {
  if (host !== '127.0.0.1') {
    throw new Error('Access gateway may only listen on IPv4 loopback.');
  }
  if (!Number.isSafeInteger(failureCapacity) || failureCapacity < 1) {
    throw new Error('Failure limiter capacity must be a positive integer.');
  }
  const publicOrigin = assertCleanHttpsOrigin(origin);
  const [config, loginTemplate, loginScript] = await Promise.all([
    loadConfig(configPath),
    readFile(loginHtmlPath, 'utf8'),
    readFile(loginJsPath, 'utf8'),
  ]);
  if (!loginTemplate.includes('{{ERROR_MESSAGE}}')) {
    throw new Error('Login template is missing its error marker.');
  }
  const expectedCredential = digestCredential(config.username, config.password);
  const limiter = createFailureLimiter(now, failureCapacity);

  const server = createServer(async (request, response) => {
    try {
      const requestUrl = new URL(request.url ?? '/', publicOrigin);
      const pathname = requestUrl.pathname;

      if (request.method === 'GET' && pathname === '/login') {
        const message = requestUrl.searchParams.get('error') === 'invalid'
          ? invalidLoginMessage()
          : '';
        send(
          response,
          200,
          renderLogin(loginTemplate, message),
          'text/html; charset=utf-8',
          {
            'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; script-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
          },
        );
        return;
      }

      if (request.method === 'GET' && pathname === '/login.js') {
        send(response, 200, loginScript, 'text/javascript; charset=utf-8');
        return;
      }

      if (request.method === 'POST' && pathname === '/login') {
        if (request.headers.origin !== publicOrigin) {
          send(response, 403, 'Forbidden');
          return;
        }
        const contentType = request.headers['content-type'] ?? '';
        if (!contentType.toLowerCase().startsWith('application/x-www-form-urlencoded')) {
          send(response, 415, 'Unsupported Media Type');
          return;
        }
        const contentLength = Number(request.headers['content-length'] ?? 0);
        if (Number.isFinite(contentLength) && contentLength > MAX_FORM_BYTES) {
          send(response, 413, 'Request Entity Too Large', 'text/plain; charset=utf-8', {
            Connection: 'close',
          });
          return;
        }
        const input = await readBoundedBody(request);
        if (input.error) {
          const status = input.error === 'too-large' ? 413 : input.error === 'timeout' ? 408 : 400;
          send(response, status, status === 413 ? 'Request Entity Too Large' : 'Bad Request', 'text/plain; charset=utf-8', {
            Connection: 'close',
          });
          return;
        }
        const form = new URLSearchParams(input.body);
        const usernames = form.getAll('username');
        const passwords = form.getAll('password');
        const username = usernames.length === 1 ? usernames[0] : '';
        const password = passwords.length === 1 ? passwords[0] : '';
        const key = clientKey(request);
        const suppliedCredential = digestCredential(username, password);
        const retryAfterMs = limiter.retryAfterMs(key);
        if (retryAfterMs > 0) {
          const retryAfterSeconds = Math.max(1, Math.ceil(retryAfterMs / 1000));
          send(
            response,
            429,
            renderLogin(loginTemplate, blockedLoginMessage(retryAfterMs)),
            'text/html; charset=utf-8',
            {
              'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; script-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
              'Retry-After': String(retryAfterSeconds),
            },
          );
          return;
        }
        if (!safeEqual(suppliedCredential, expectedCredential)) {
          limiter.fail(key);
          redirect(response, '/login?error=invalid');
          return;
        }
        limiter.clear(key);
        const expiresAt = now() + sessionTtlMs;
        const session = createSessionValue(config.username, expiresAt, config.sessionSecret);
        redirect(response, '/', {
          'Set-Cookie': `${COOKIE_NAME}=${session}; Max-Age=${Math.floor(sessionTtlMs / 1000)}; Path=/; HttpOnly; Secure; SameSite=Strict`,
        });
        return;
      }

      if (request.method === 'POST' && pathname === '/logout') {
        if (request.headers.origin !== publicOrigin) {
          send(response, 403, 'Forbidden');
          return;
        }
        redirect(response, '/login', {
          'Set-Cookie': `${COOKIE_NAME}=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Strict`,
        });
        return;
      }

      if (request.method === 'GET' && pathname === '/verify') {
        const session = cookieValue(request, COOKIE_NAME);
        if (verifySessionValue(session, config, now)) {
          send(response, 204, '');
          return;
        }
        const requestedUri = parseForwardedUri(request);
        if (isApiUri(requestedUri)) {
          send(response, 401, JSON.stringify({ error: 'authentication_required' }), 'application/json; charset=utf-8');
        } else {
          redirect(response, '/login', {}, 302);
        }
        return;
      }

      send(response, 404, 'Not Found');
    } catch {
      if (!response.headersSent) send(response, 500, 'Internal Server Error');
      else response.destroy();
    }
  });
  server.headersTimeout = 10_000;
  server.requestTimeout = 10_000;
  server.keepAliveTimeout = 5_000;
  server.maxHeadersCount = 64;
  server.on('clientError', (_error, socket) => {
    if (socket.writable) socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n');
  });

  await new Promise((resolveListen, rejectListen) => {
    server.once('error', rejectListen);
    server.listen(port, host, () => {
      server.off('error', rejectListen);
      resolveListen();
    });
  });
  const address = server.address();
  return Object.freeze({
    host,
    port: typeof address === 'object' && address ? address.port : port,
    close: () => new Promise((resolveClose, rejectClose) => {
      server.close((error) => error ? rejectClose(error) : resolveClose());
    }),
  });
}

if (import.meta.main) {
  const gateway = await startAccessGateway();
  console.log(`[popi-access] ready on loopback:${gateway.port}`);
  let closing = false;
  const shutdown = async () => {
    if (closing) return;
    closing = true;
    try {
      await gateway.close();
    } catch {
      console.error('[popi-access] graceful shutdown failed');
      process.exitCode = 1;
    }
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}
