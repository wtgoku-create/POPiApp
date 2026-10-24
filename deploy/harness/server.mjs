import { isAbsolute } from 'node:path';
import { startLocalApi } from '../../services/agent/local/server.mjs';

const publicOrigin = new URL(process.env.POPI_HARNESS_PUBLIC_ORIGIN);
if (publicOrigin.protocol !== 'https:' || publicOrigin.origin !== publicOrigin.href.replace(/\/$/, '') || publicOrigin.username || publicOrigin.password) {
  throw new Error('POPI_HARNESS_PUBLIC_ORIGIN must be a clean HTTPS origin.');
}
const stateRoot = process.env.POPI_HARNESS_STATE_ROOT;
if (!stateRoot || !isAbsolute(stateRoot)) {
  throw new Error('POPI_HARNESS_STATE_ROOT must be an absolute private directory.');
}

// Public authentication and TLS terminate at Caddy; this API stays loopback-only.
const service = await startLocalApi({
  host: '127.0.0.1',
  port: 3084,
  stateRoot,
  allowedOrigins: new Set([publicOrigin.origin, 'http://127.0.0.1:7357']),
});
console.log(`[popi-harness] ready on loopback:${service.port}`);
let closing = false;
const shutdown = async () => {
  if (closing) return;
  closing = true;
  try {
    await service.close();
  } catch {
    console.error('[popi-harness] graceful shutdown failed');
    process.exitCode = 1;
  }
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
