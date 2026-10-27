import http from 'node:http';
import { createReadStream } from 'node:fs';
import { readFile, realpath, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

const ADMIN_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.dirname(ADMIN_DIR);
const DEFAULT_STATIC_DIR = path.join(ADMIN_DIR, 'public');
const DEFAULT_PORT = 7360;
const MAX_BODY_BYTES = 64 * 1024;
const UPSTREAM_TIMEOUT_MS = 30_000;
const UUID_PATTERN = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
const SESSION_PATTERN = new RegExp(`^/api_agent/v2/sessions/(${UUID_PATTERN})$`);
const SNAPSHOT_PATTERN = new RegExp(`^/api_agent/v2/sessions/(${UUID_PATTERN})/snapshot$`);
const STOP_PATTERN = new RegExp(`^/api_agent/v2/sessions/(${UUID_PATTERN})/stop$`);
const ASSET_PATTERN = new RegExp(`^/api_agent/v2/assets/(${UUID_PATTERN})/(content|poster)$`);
const CSP = "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'none'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src 'self'";

const CONTENT_TYPES = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.mjs', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.webp', 'image/webp'],
]);

const FORWARDED_RESPONSE_HEADERS = new Set([
  'accept-ranges',
  'cache-control',
  'content-disposition',
  'content-length',
  'content-range',
  'content-type',
  'etag',
  'last-modified',
]);

function applySecurityHeaders(response) {
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Content-Security-Policy', CSP);
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
}

function sendJson(request, response, statusCode, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  response.statusCode = statusCode;
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('Content-Length', body.length);
  response.end(request.method === 'HEAD' ? undefined : body);
}

function sendError(request, response, statusCode, code, message) {
  sendJson(request, response, statusCode, { error: { code, message } });
}

function isLoopbackHostname(hostname) {
  const normalized = hostname.toLowerCase().replace(/^\[|\]$/g, '');
  if (normalized === 'localhost' || normalized === '::1') return true;
  const parts = normalized.split('.');
  return parts.length === 4
    && parts[0] === '127'
    && parts.every((part) => /^\d+$/.test(part) && Number(part) <= 255);
}

function validateLoopbackUrl(value, fieldName) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`${fieldName} 缺失`);
  }

  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`${fieldName} 不是有效 URL`);
  }

  if (
    parsed.protocol !== 'http:'
    || !isLoopbackHostname(parsed.hostname)
    || parsed.username
    || parsed.password
    || parsed.pathname !== '/'
    || parsed.search
    || parsed.hash
  ) {
    throw new Error(`${fieldName} 必须是无路径的本机 HTTP 地址`);
  }
  return parsed.origin;
}

async function loadEnvironment(environment, projectRoot) {
  let configPath;
  if (path.isAbsolute(environment)) {
    if (path.extname(environment).toLowerCase() !== '.json') {
      throw new Error('--env 绝对路径必须指向 JSON 文件');
    }
    configPath = environment;
  } else {
    if (!/^[a-zA-Z0-9_-]+$/.test(environment)) {
      throw new Error('--env 名称无效');
    }
    configPath = path.join(projectRoot, 'config', 'env', `${environment}.json`);
  }

  let parsed;
  try {
    parsed = JSON.parse(await readFile(configPath, 'utf8'));
  } catch (error) {
    throw new Error(`无法读取环境配置：${error.message}`);
  }

  return {
    agentBaseUrl: validateLoopbackUrl(parsed.AGENT_API_BASE_URL, 'AGENT_API_BASE_URL'),
    agentOrigin: validateLoopbackUrl(parsed.AGENT_API_ORIGIN, 'AGENT_API_ORIGIN'),
  };
}

function getRequestAuthority(request, server) {
  const host = request.headers.host;
  if (typeof host !== 'string' || host.includes(',')) return null;

  let parsed;
  try {
    parsed = new URL(`http://${host}`);
  } catch {
    return null;
  }

  const address = server.address();
  const expectedPort = typeof address === 'object' && address ? String(address.port) : '';
  if (!isLoopbackHostname(parsed.hostname) || (parsed.port || '80') !== expectedPort) return null;
  return parsed.origin;
}

function validateRequestSource(request, response, server, requiresOrigin) {
  const authority = getRequestAuthority(request, server);
  if (!authority) {
    sendError(request, response, 400, 'INVALID_HOST', '仅允许通过本机服务地址访问');
    return false;
  }

  const origin = request.headers.origin;
  if ((requiresOrigin && !origin) || (origin && origin !== authority)) {
    sendError(request, response, 403, 'INVALID_ORIGIN', '请求来源不受信任');
    return false;
  }
  return true;
}

function hasOnlyQueryParameters(url, allowed) {
  const seen = new Set();
  for (const key of url.searchParams.keys()) {
    if (!allowed.has(key) || seen.has(key)) return false;
    seen.add(key);
  }
  return true;
}

function classifyApiRequest(method, url) {
  const { pathname } = url;
  if (pathname === '/health') {
    return ['GET', 'HEAD'].includes(method) && url.search === '' ? { kind: 'proxy' } : { kind: 'method-or-query' };
  }
  if (pathname === '/api_agent/v2/capabilities') {
    return method === 'GET' && url.search === '' ? { kind: 'proxy' } : { kind: 'method-or-query' };
  }
  if (pathname === '/api_agent/v2/sessions') {
    return method === 'GET' && hasOnlyQueryParameters(url, new Set(['page', 'pageSize', 'archived']))
      ? { kind: 'proxy' }
      : { kind: 'method-or-query' };
  }
  if (SNAPSHOT_PATTERN.test(pathname)) {
    return method === 'GET' && url.search === '' ? { kind: 'proxy' } : { kind: 'method-or-query' };
  }
  if (pathname === '/api_agent/v2/assets') {
    return ['GET', 'HEAD'].includes(method) && hasOnlyQueryParameters(url, new Set(['sessionId']))
      ? { kind: 'proxy', media: true }
      : { kind: 'method-or-query' };
  }
  if (ASSET_PATTERN.test(pathname)) {
    return ['GET', 'HEAD'].includes(method) && url.search === ''
      ? { kind: 'proxy', media: true }
      : { kind: 'method-or-query' };
  }
  if (SESSION_PATTERN.test(pathname)) {
    return method === 'PATCH' && url.search === '' ? { kind: 'patch' } : { kind: 'method-or-query' };
  }
  if (STOP_PATTERN.test(pathname)) {
    return method === 'POST' && url.search === '' ? { kind: 'stop' } : { kind: 'method-or-query' };
  }
  if (pathname === '/admin-config') {
    return method === 'GET' && url.search === '' ? { kind: 'config' } : { kind: 'method-or-query' };
  }
  if (pathname === '/health' || pathname.startsWith('/api_agent/') || pathname === '/admin-config') {
    return { kind: 'unknown-api' };
  }
  return null;
}

async function readJsonBody(request) {
  const contentType = request.headers['content-type']?.split(';', 1)[0].trim().toLowerCase();
  if (contentType !== 'application/json') {
    const error = new Error('写操作必须使用 application/json');
    error.statusCode = 415;
    error.code = 'UNSUPPORTED_MEDIA_TYPE';
    throw error;
  }

  const declaredLength = Number(request.headers['content-length']);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    request.resume();
    const error = new Error('请求体过大');
    error.statusCode = 413;
    error.code = 'BODY_TOO_LARGE';
    throw error;
  }

  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) {
      const error = new Error('请求体过大');
      error.statusCode = 413;
      error.code = 'BODY_TOO_LARGE';
      throw error;
    }
    chunks.push(chunk);
  }

  try {
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error();
    return body;
  } catch {
    const error = new Error('请求体不是有效的 JSON 对象');
    error.statusCode = 400;
    error.code = 'INVALID_JSON';
    throw error;
  }
}

function validateWriteBody(kind, input) {
  const allowedKeys = kind === 'patch'
    ? new Set(['clientRequestId', 'title', 'archived', 'pinned'])
    : new Set(['clientRequestId']);
  const keys = Object.keys(input);
  if (keys.some((key) => !allowedKeys.has(key))) {
    throw Object.assign(new Error('请求包含不允许的字段'), { statusCode: 400, code: 'INVALID_FIELDS' });
  }
  if (kind === 'patch' && !keys.some((key) => key !== 'clientRequestId')) {
    throw Object.assign(new Error('没有可更新的字段'), { statusCode: 400, code: 'INVALID_FIELDS' });
  }
  if (!keys.includes('clientRequestId')) {
    throw Object.assign(new Error('缺少 clientRequestId'), { statusCode: 400, code: 'INVALID_FIELDS' });
  }
  if (typeof input.clientRequestId !== 'string' || input.clientRequestId.trim().length === 0 || input.clientRequestId.length > 128) {
    throw Object.assign(new Error('clientRequestId 无效'), { statusCode: 400, code: 'INVALID_FIELDS' });
  }
  if ('title' in input && (typeof input.title !== 'string' || input.title.trim().length === 0 || input.title.length > 120)) {
    throw Object.assign(new Error('title 无效'), { statusCode: 400, code: 'INVALID_FIELDS' });
  }
  for (const key of ['archived', 'pinned']) {
    if (key in input && typeof input[key] !== 'boolean') {
      throw Object.assign(new Error(`${key} 无效`), { statusCode: 400, code: 'INVALID_FIELDS' });
    }
  }
  return Object.fromEntries(keys.map((key) => [key, input[key]]));
}

async function proxyRequest(request, response, rawTarget, route, environmentConfig) {
  const headers = new Headers({
    Accept: request.headers.accept || 'application/json',
    'Accept-Encoding': 'identity',
    Origin: environmentConfig.agentOrigin,
  });
  if (route.media && request.headers.range) headers.set('Range', request.headers.range);
  if (route.media && request.headers['if-range']) headers.set('If-Range', request.headers['if-range']);

  let body;
  if (route.kind === 'patch' || route.kind === 'stop') {
    try {
      body = JSON.stringify(validateWriteBody(route.kind, await readJsonBody(request)));
    } catch (error) {
      sendError(request, response, error.statusCode || 400, error.code || 'INVALID_BODY', error.message);
      return;
    }
    headers.set('Content-Type', 'application/json');
  }

  let upstream;
  try {
    upstream = await fetch(`${environmentConfig.agentBaseUrl}${rawTarget}`, {
      method: request.method,
      headers,
      body,
      redirect: 'manual',
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    });
  } catch (error) {
    const timedOut = error.name === 'TimeoutError' || error.name === 'AbortError';
    sendError(
      request,
      response,
      502,
      timedOut ? 'UPSTREAM_TIMEOUT' : 'UPSTREAM_UNAVAILABLE',
      timedOut ? 'Agent 服务响应超时' : 'Agent 服务暂时不可用',
    );
    return;
  }

  response.statusCode = upstream.status;
  for (const [name, value] of upstream.headers) {
    if (FORWARDED_RESPONSE_HEADERS.has(name.toLowerCase())) response.setHeader(name, value);
  }
  response.setHeader('Cache-Control', 'no-store');

  if (request.method === 'HEAD' || !upstream.body) {
    response.end();
    return;
  }

  try {
    await pipeline(Readable.fromWeb(upstream.body), response);
  } catch {
    if (!response.headersSent) {
      sendError(request, response, 502, 'UPSTREAM_STREAM_ERROR', '读取 Agent 服务响应失败');
    } else {
      response.destroy();
    }
  }
}

async function serveStatic(request, response, url, staticDir) {
  if (!['GET', 'HEAD'].includes(request.method)) {
    sendError(request, response, 405, 'METHOD_NOT_ALLOWED', '不支持此请求方法');
    return;
  }
  if (url.search) {
    sendError(request, response, 404, 'NOT_FOUND', '资源不存在');
    return;
  }

  const rawPath = request.url.split('?', 1)[0];
  let decodedPath;
  try {
    decodedPath = decodeURIComponent(rawPath);
  } catch {
    sendError(request, response, 400, 'INVALID_PATH', '路径无效');
    return;
  }
  if (decodedPath.includes('\\') || decodedPath.includes('\0') || decodedPath.split('/').includes('..')) {
    sendError(request, response, 400, 'INVALID_PATH', '路径无效');
    return;
  }

  const relativePath = decodedPath === '/' ? 'index.html' : decodedPath.slice(1);
  const root = path.resolve(staticDir);
  const candidate = path.resolve(root, relativePath);
  if (candidate !== root && !candidate.startsWith(`${root}${path.sep}`)) {
    sendError(request, response, 400, 'INVALID_PATH', '路径无效');
    return;
  }

  try {
    const [rootRealPath, fileRealPath, fileStat] = await Promise.all([
      realpath(root),
      realpath(candidate),
      stat(candidate),
    ]);
    if (!fileStat.isFile() || (fileRealPath !== rootRealPath && !fileRealPath.startsWith(`${rootRealPath}${path.sep}`))) {
      throw new Error('not a public file');
    }
    response.statusCode = 200;
    response.setHeader('Content-Length', fileStat.size);
    response.setHeader('Content-Type', CONTENT_TYPES.get(path.extname(fileRealPath).toLowerCase()) || 'application/octet-stream');
    if (request.method === 'HEAD') {
      response.end();
    } else {
      await pipeline(createReadStream(fileRealPath), response);
    }
  } catch {
    if (!response.headersSent) sendError(request, response, 404, 'NOT_FOUND', '资源不存在');
    else response.destroy();
  }
}

export async function startAdminServer({
  port = DEFAULT_PORT,
  host = '127.0.0.1',
  environment = 'harness',
  projectRoot = PROJECT_ROOT,
  staticDir = DEFAULT_STATIC_DIR,
} = {}) {
  if (!Number.isInteger(port) || port < 0 || port > 65_535) throw new Error('端口无效');
  if (!isLoopbackHostname(host)) throw new Error('管理后台只能监听本机回环地址');
  const environmentConfig = await loadEnvironment(environment, projectRoot);

  let server;
  server = http.createServer(async (request, response) => {
    applySecurityHeaders(response);
    try {
      if (!validateRequestSource(request, response, server, false)) return;

      const rawTarget = request.url;
      if (typeof rawTarget !== 'string' || !rawTarget.startsWith('/') || rawTarget.startsWith('//') || rawTarget.includes('#')) {
        sendError(request, response, 400, 'INVALID_PATH', '路径无效');
        return;
      }

      let url;
      try {
        url = new URL(rawTarget, environmentConfig.agentBaseUrl);
      } catch {
        sendError(request, response, 400, 'INVALID_PATH', '路径无效');
        return;
      }
      const route = classifyApiRequest(request.method, url);
      if (!route) {
        await serveStatic(request, response, url, staticDir);
        return;
      }
      if (route.kind === 'unknown-api') {
        sendError(request, response, 404, 'NOT_FOUND', '接口不存在');
        return;
      }
      if (route.kind === 'method-or-query') {
        sendError(request, response, 405, 'METHOD_NOT_ALLOWED', '请求方法或参数不受支持');
        return;
      }
      if (route.kind === 'config') {
        sendJson(request, response, 200, {
          environment: path.isAbsolute(environment) ? path.basename(environment, '.json') : environment,
          agentBaseUrl: environmentConfig.agentBaseUrl,
        });
        return;
      }

      const isWrite = route.kind === 'patch' || route.kind === 'stop';
      if (!validateRequestSource(request, response, server, isWrite)) return;
      await proxyRequest(request, response, rawTarget, route, environmentConfig);
    } catch {
      if (!response.headersSent) sendError(request, response, 500, 'INTERNAL_ERROR', '管理后台处理请求失败');
      else response.destroy();
    }
  });

  await new Promise((resolve, reject) => {
    const onError = (error) => {
      server.off('listening', onListening);
      reject(error);
    };
    const onListening = () => {
      server.off('error', onError);
      resolve();
    };
    server.once('error', onError);
    server.once('listening', onListening);
    server.listen(port, host);
  });

  const address = server.address();
  const actualPort = typeof address === 'object' && address ? address.port : port;
  return {
    server,
    host,
    port: actualPort,
    url: `http://${host.includes(':') ? `[${host}]` : host}:${actualPort}`,
  };
}

function parseCliArguments(argv) {
  let port = DEFAULT_PORT;
  let environment = 'harness';
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--port' || argument === '--env') {
      const value = argv[index + 1];
      if (!value) throw new Error(`${argument} 缺少参数`);
      if (argument === '--port') port = Number(value);
      else environment = value;
      index += 1;
    } else if (argument.startsWith('--port=')) {
      port = Number(argument.slice('--port='.length));
    } else if (argument.startsWith('--env=')) {
      environment = argument.slice('--env='.length);
    } else {
      throw new Error(`未知参数：${argument}`);
    }
  }
  return { port, environment };
}

const isCli = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isCli) {
  try {
    const options = parseCliArguments(process.argv.slice(2));
    const running = await startAdminServer(options);
    console.log(`POPi 本机管理后台：http://127.0.0.1:${running.port}`);
  } catch (error) {
    console.error(`启动失败：${error.message}`);
    process.exitCode = 1;
  }
}
