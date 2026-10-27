import { chmodSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { parseArgs } from 'node:util';

try {
  const { values } = parseArgs({ options: {
    'harness-source': { type: 'string' },
    output: { type: 'string' },
    origin: { type: 'string', default: 'https://124.222.185.31' },
  } });
  if (!values['harness-source'] || !values.output) throw new Error();
  const origin = new URL(values.origin);
  if (origin.protocol !== 'https:' || values.origin !== origin.origin) throw new Error();
  const source = resolve(values['harness-source']);
  const target = resolve(values.output);
  const require = createRequire(source + '/services/agent/runtime/package.json');
  const yaml = require('yaml');
  const privateRoot = source + '/services/agent/.local/local-api';
  const model = JSON.parse(readFileSync(privateRoot + '/model.json', 'utf8'));
  const document = yaml.parse(readFileSync(model.credentialsFile, 'utf8'));
  const reference = model.credentialRef ?? 'DEEPSEEK_API_KEY';
  if (typeof document.refs[reference] !== 'string' || !document.refs[reference]) throw new Error();
  // Transfer the model reference only, never the unrelated browser-session record.
  const credentials = { version: document.version, refs: { [reference]: document.refs[reference] } };
  model.credentialsFile = '/etc/popi-harness/.credentials.yaml';
  const media = readFileSync(privateRoot + '/huimengi.json', 'utf8');
  JSON.parse(media);
  const files = {
    'model.json': JSON.stringify(model, null, 2) + '\n',
    'huimengi.json': media,
    '.credentials.yaml': yaml.stringify(credentials),
    'service.env': `POPI_HARNESS_PUBLIC_ORIGIN=${origin.origin}\nPOPI_HARNESS_STATE_ROOT=/var/lib/popi-harness\nLOCAL_AGENT_MODEL_CONFIG=/etc/popi-harness/model.json\nLOCAL_AGENT_MULTIMODAL_CONFIG=/etc/popi-harness/huimengi.json\nPATH=/opt/popi-harness/node/bin:/usr/bin:/bin\n`,
  };
  mkdirSync(target, { recursive: true, mode: 0o700 });
  chmodSync(target, 0o700);
  for (const [name, content] of Object.entries(files)) {
    writeFileSync(target + '/' + name, content, { mode: 0o600 });
    chmodSync(target + '/' + name, 0o600);
  }
  console.log('Prepared owner-only provider configuration; no secret values emitted.');
} catch {
  console.error('Private configuration preparation failed. Check paths, HTTPS origin and credential reference.');
  process.exitCode = 1;
}
