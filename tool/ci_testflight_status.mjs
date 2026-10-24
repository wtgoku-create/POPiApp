#!/usr/bin/env node

import {
  createPrivateKey,
  generateKeyPairSync,
  sign,
  verify,
} from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const API_ORIGIN = 'https://api.appstoreconnect.apple.com';
const READY_INTERNAL_STATES = new Set([
  'READY_FOR_BETA_TESTING',
  'IN_BETA_TESTING',
]);

class AppStoreConnectError extends Error {
  constructor(status, code) {
    super(`App Store Connect request failed with HTTP ${status}.`);
    this.name = 'AppStoreConnectError';
    this.status = status;
    this.code = code;
  }
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

export function createAppStoreConnectToken({
  issuerId,
  keyId,
  privateKey,
  nowSeconds = Math.floor(Date.now() / 1000),
}) {
  const header = base64Url(
    JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }),
  );
  const payload = base64Url(
    JSON.stringify({
      iss: issuerId,
      iat: nowSeconds - 5,
      exp: nowSeconds + 600,
      aud: 'appstoreconnect-v1',
    }),
  );
  const signingInput = `${header}.${payload}`;
  const signingKey =
    privateKey?.type === 'private' && privateKey?.asymmetricKeyType
      ? privateKey
      : createPrivateKey(privateKey);
  const signature = sign('sha256', Buffer.from(signingInput), {
    key: signingKey,
    dsaEncoding: 'ieee-p1363',
  });
  return `${signingInput}.${signature.toString('base64url')}`;
}

function parseArguments(argv) {
  const options = {
    waitSeconds: 0,
    pollSeconds: 20,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--self-test') {
      options.selfTest = true;
      continue;
    }
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for ${argument}.`);
    }
    index += 1;
    switch (argument) {
      case '--bundle-id':
        options.bundleId = value;
        break;
      case '--build-number':
        options.buildNumber = value;
        break;
      case '--version':
        options.version = value;
        break;
      case '--private-key-file':
        options.privateKeyFile = value;
        break;
      case '--output':
        options.output = value;
        break;
      case '--wait-seconds':
        options.waitSeconds = Number.parseInt(value, 10);
        break;
      case '--poll-seconds':
        options.pollSeconds = Number.parseInt(value, 10);
        break;
      default:
        throw new Error(`Unknown argument: ${argument}`);
    }
  }
  return options;
}

function requireNonEmpty(value, label) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${label} is required.`);
  }
  return value.trim();
}

function safePublicLink(value) {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value);
    if (
      url.protocol !== 'https:' ||
      url.hostname !== 'testflight.apple.com' ||
      !/^\/join\/[A-Za-z0-9]+$/.test(url.pathname) ||
      url.search !== '' ||
      url.hash !== ''
    ) {
      return null;
    }
    return url.toString();
  } catch {
    return null;
  }
}

function relationshipIds(resource, relationshipName) {
  const data = resource?.relationships?.[relationshipName]?.data;
  const items = Array.isArray(data) ? data : data ? [data] : [];
  return new Set(
    items
      .filter((item) => item && typeof item.id === 'string')
      .map((item) => item.id),
  );
}

function includedByType(document, type) {
  return (Array.isArray(document?.included) ? document.included : []).filter(
    (item) => item?.type === type,
  );
}

export function summarizeTestFlightStatus({
  bundleId,
  expectedVersion,
  expectedBuildNumber,
  appDocument,
  buildDocument,
  groupsDocument,
  queriedAt,
  warnings = [],
}) {
  const app = appDocument.data[0];
  const builds = Array.isArray(buildDocument?.data) ? buildDocument.data : [];
  const build = builds
    .filter((item) => item?.attributes?.version === expectedBuildNumber)
    .sort((left, right) =>
      String(right?.attributes?.uploadedDate ?? '').localeCompare(
        String(left?.attributes?.uploadedDate ?? ''),
      ),
    )[0];

  const base = {
    schemaVersion: 1,
    status: warnings.length === 0 ? 'ok' : 'partial',
    queriedAt,
    bundleId,
    appName:
      typeof app?.attributes?.name === 'string' ? app.attributes.name : null,
    requestedVersion: expectedVersion,
    requestedBuildNumber: expectedBuildNumber,
    build: null,
    betaGroups: {
      querySucceeded: groupsDocument !== null,
      externalGroupCount: null,
      publicLinkEnabledGroupCount: null,
    },
    publicLinks: [],
    warnings,
  };

  if (!build) {
    base.build = {
      found: false,
      processed: false,
      processingSucceeded: false,
      internalTestable: false,
      externalTestable: false,
    };
    if (!base.warnings.includes('BUILD_NOT_YET_VISIBLE')) {
      base.warnings.push('BUILD_NOT_YET_VISIBLE');
      base.status = 'partial';
    }
    return base;
  }

  const prereleaseVersion = includedByType(
    buildDocument,
    'preReleaseVersions',
  ).find((item) =>
    relationshipIds(build, 'preReleaseVersion').has(item.id),
  );
  const betaDetail = includedByType(buildDocument, 'buildBetaDetails').find(
    (item) => relationshipIds(build, 'buildBetaDetail').has(item.id),
  );
  const assignedGroupIds = relationshipIds(build, 'betaGroups');
  const attributes = build.attributes ?? {};
  const processingState = attributes.processingState ?? null;
  const internalState = betaDetail?.attributes?.internalBuildState ?? null;
  const externalState = betaDetail?.attributes?.externalBuildState ?? null;
  const actualVersion = prereleaseVersion?.attributes?.version ?? null;
  const expired = attributes.expired === true;

  base.build = {
    found: true,
    version: actualVersion,
    buildNumber: attributes.version ?? null,
    uploadedDate: attributes.uploadedDate ?? null,
    expirationDate: attributes.expirationDate ?? null,
    expired,
    processingState,
    processed: processingState !== null && processingState !== 'PROCESSING',
    processingSucceeded: processingState === 'VALID',
    internalState,
    externalState,
    internalTestable:
      processingState === 'VALID' &&
      !expired &&
      READY_INTERNAL_STATES.has(internalState),
    externalTestable:
      processingState === 'VALID' &&
      !expired &&
      externalState === 'IN_BETA_TESTING',
  };

  if (actualVersion !== null && actualVersion !== expectedVersion) {
    base.warnings.push('VERSION_MISMATCH');
    base.status = 'partial';
  }

  if (groupsDocument !== null) {
    const groups = Array.isArray(groupsDocument.data) ? groupsDocument.data : [];
    const externalGroups = groups.filter(
      (group) => group?.attributes?.isInternalGroup === false,
    );
    const publicGroups = externalGroups.filter(
      (group) => group?.attributes?.publicLinkEnabled === true,
    );
    base.betaGroups.externalGroupCount = externalGroups.length;
    base.betaGroups.publicLinkEnabledGroupCount = publicGroups.length;
    base.publicLinks = publicGroups.map((group) => {
      const groupAttributes = group.attributes ?? {};
      const url = safePublicLink(groupAttributes.publicLink);
      const assignedToBuild = assignedGroupIds.has(group.id);
      const hasAccessToAllBuilds =
        groupAttributes.hasAccessToAllBuilds === true;
      return {
        groupName:
          typeof groupAttributes.name === 'string'
            ? groupAttributes.name
            : null,
        enabled: true,
        url,
        assignedToBuild,
        hasAccessToAllBuilds,
        installable:
          url !== null &&
          base.build.externalTestable &&
          (assignedToBuild || hasAccessToAllBuilds),
      };
    });
  }

  return base;
}

function publicError(error) {
  if (error instanceof AppStoreConnectError) {
    return {
      kind: 'app_store_connect_api',
      httpStatus: error.status,
      code: error.code,
    };
  }
  if (error?.name === 'AbortError') {
    return { kind: 'network_timeout' };
  }
  return { kind: 'query_failed' };
}

async function apiGet(token, endpoint, query = {}) {
  const url = new URL(endpoint, API_ORIGIN);
  if (url.origin !== API_ORIGIN) {
    throw new Error('Refusing to query a non-App Store Connect origin.');
  }
  for (const [name, value] of Object.entries(query)) {
    if (value !== undefined && value !== null) {
      url.searchParams.set(name, String(value));
    }
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);
  try {
    const response = await fetch(url, {
      method: 'GET',
      redirect: 'error',
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${token}`,
      },
    });
    if (!response.ok) {
      let code = null;
      try {
        const body = await response.json();
        code =
          typeof body?.errors?.[0]?.code === 'string'
            ? body.errors[0].code
            : null;
      } catch {
        // The public status intentionally omits arbitrary response bodies.
      }
      throw new AppStoreConnectError(response.status, code);
    }
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

async function queryStatus(options) {
  const issuerId = requireNonEmpty(
    process.env.APPSTORE_ISSUER_ID,
    'APPSTORE_ISSUER_ID',
  );
  const keyId = requireNonEmpty(
    process.env.APPSTORE_KEY_ID,
    'APPSTORE_KEY_ID',
  );
  const privateKey = await readFile(
    requireNonEmpty(options.privateKeyFile, '--private-key-file'),
    'utf8',
  );
  const bundleId = requireNonEmpty(options.bundleId, '--bundle-id');
  const expectedVersion = requireNonEmpty(options.version, '--version');
  const expectedBuildNumber = requireNonEmpty(
    options.buildNumber,
    '--build-number',
  );
  const token = createAppStoreConnectToken({
    issuerId,
    keyId,
    privateKey,
  });

  const appDocument = await apiGet(token, '/v1/apps', {
    'filter[bundleId]': bundleId,
    'fields[apps]': 'name,bundleId',
    limit: 2,
  });
  if (!Array.isArray(appDocument.data) || appDocument.data.length !== 1) {
    throw new AppStoreConnectError(404, 'APP_NOT_FOUND');
  }
  const appId = appDocument.data[0].id;

  const deadline = Date.now() + options.waitSeconds * 1000;
  let buildDocument = { data: [], included: [] };
  do {
    buildDocument = await apiGet(token, '/v1/builds', {
      'filter[app]': appId,
      'filter[version]': expectedBuildNumber,
      'filter[preReleaseVersion.platform]': 'IOS',
      'fields[builds]':
        'version,uploadedDate,expirationDate,expired,processingState,buildAudienceType,preReleaseVersion,betaGroups,buildBetaDetail',
      include: 'preReleaseVersion,betaGroups,buildBetaDetail',
      'fields[preReleaseVersions]': 'version,platform',
      'fields[betaGroups]':
        'name,isInternalGroup,hasAccessToAllBuilds,publicLinkEnabled,publicLink',
      'fields[buildBetaDetails]':
        'internalBuildState,externalBuildState',
      'limit[betaGroups]': 50,
      limit: 10,
      sort: '-uploadedDate',
    });
    const build = Array.isArray(buildDocument.data)
      ? buildDocument.data.find(
          (item) => item?.attributes?.version === expectedBuildNumber,
        )
      : null;
    if (build && build?.attributes?.processingState !== 'PROCESSING') break;
    if (Date.now() >= deadline) break;
    await new Promise((resolve) =>
      setTimeout(resolve, options.pollSeconds * 1000),
    );
  } while (true);

  const warnings = [];
  let groupsDocument = null;
  try {
    groupsDocument = await apiGet(
      token,
      `/v1/apps/${encodeURIComponent(appId)}/betaGroups`,
      {
        'fields[betaGroups]':
          'name,isInternalGroup,hasAccessToAllBuilds,publicLinkEnabled,publicLink',
        limit: 200,
      },
    );
    if (groupsDocument?.links?.next) warnings.push('BETA_GROUPS_TRUNCATED');
  } catch {
    warnings.push('BETA_GROUP_QUERY_FAILED');
  }

  return summarizeTestFlightStatus({
    bundleId,
    expectedVersion,
    expectedBuildNumber,
    appDocument,
    buildDocument,
    groupsDocument,
    queriedAt: new Date().toISOString(),
    warnings,
  });
}

async function writeResult(outputPath, result) {
  await mkdir(path.dirname(outputPath), { recursive: true });
  await writeFile(outputPath, `${JSON.stringify(result, null, 2)}\n`, {
    mode: 0o644,
  });
}

async function runSelfTest() {
  const { privateKey, publicKey } = generateKeyPairSync('ec', {
    namedCurve: 'P-256',
  });
  const token = createAppStoreConnectToken({
    issuerId: '00000000-0000-0000-0000-000000000000',
    keyId: 'TESTKEY123',
    privateKey: privateKey.export({ type: 'pkcs8', format: 'pem' }),
    nowSeconds: 1_700_000_000,
  });
  const [header, payload, signature] = token.split('.');
  if (
    !verify(
      'sha256',
      Buffer.from(`${header}.${payload}`),
      { key: publicKey, dsaEncoding: 'ieee-p1363' },
      Buffer.from(signature, 'base64url'),
    )
  ) {
    throw new Error('JWT signature self-test failed.');
  }

  const appDocument = {
    data: [
      {
        type: 'apps',
        id: 'app-fixture',
        attributes: { name: 'POPi', bundleId: 'com.popistudio.app' },
      },
    ],
  };
  const buildDocument = {
    data: [
      {
        type: 'builds',
        id: 'build-fixture',
        attributes: {
          version: '42101',
          uploadedDate: '2026-10-24T08:00:00Z',
          expirationDate: '2027-01-22T08:00:00Z',
          expired: false,
          processingState: 'VALID',
        },
        relationships: {
          preReleaseVersion: {
            data: { type: 'preReleaseVersions', id: 'version-fixture' },
          },
          buildBetaDetail: {
            data: { type: 'buildBetaDetails', id: 'detail-fixture' },
          },
          betaGroups: {
            data: [{ type: 'betaGroups', id: 'group-fixture' }],
          },
        },
      },
    ],
    included: [
      {
        type: 'preReleaseVersions',
        id: 'version-fixture',
        attributes: { version: '1.0.0', platform: 'IOS' },
      },
      {
        type: 'buildBetaDetails',
        id: 'detail-fixture',
        attributes: {
          internalBuildState: 'IN_BETA_TESTING',
          externalBuildState: 'IN_BETA_TESTING',
        },
      },
    ],
  };
  const groupsDocument = {
    data: [
      {
        type: 'betaGroups',
        id: 'group-fixture',
        attributes: {
          name: 'Public beta',
          isInternalGroup: false,
          hasAccessToAllBuilds: false,
          publicLinkEnabled: true,
          publicLink: 'https://testflight.apple.com/join/AbCd1234',
          ignoredTesterEmail: 'fixture@example.com',
        },
      },
      {
        type: 'betaGroups',
        id: 'internal-fixture',
        attributes: {
          name: 'Secret internal group',
          isInternalGroup: true,
          hasAccessToAllBuilds: true,
          publicLinkEnabled: false,
        },
      },
    ],
  };
  const result = summarizeTestFlightStatus({
    bundleId: 'com.popistudio.app',
    expectedVersion: '1.0.0',
    expectedBuildNumber: '42101',
    appDocument,
    buildDocument,
    groupsDocument,
    queriedAt: '2026-10-24T08:01:00Z',
  });
  if (
    result.status !== 'ok' ||
    result.build.externalTestable !== true ||
    result.publicLinks.length !== 1 ||
    result.publicLinks[0].installable !== true
  ) {
    throw new Error('Status summarization self-test failed.');
  }
  const serialized = JSON.stringify(result);
  if (
    serialized.includes('fixture@example.com') ||
    serialized.includes('Secret internal group') ||
    serialized.includes('app-fixture') ||
    serialized.includes('build-fixture')
  ) {
    throw new Error('Public status contains private fixture data.');
  }
  if (safePublicLink('https://example.com/join/AbCd1234') !== null) {
    throw new Error('Public-link origin validation self-test failed.');
  }
  process.stdout.write('ci_testflight_status self-test passed.\n');
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.selfTest) {
    await runSelfTest();
    return;
  }
  const output = requireNonEmpty(options.output, '--output');
  if (
    !Number.isInteger(options.waitSeconds) ||
    options.waitSeconds < 0 ||
    !Number.isInteger(options.pollSeconds) ||
    options.pollSeconds < 1
  ) {
    throw new Error('Polling values must be non-negative whole seconds.');
  }

  let result;
  try {
    result = await queryStatus(options);
  } catch (error) {
    result = {
      schemaVersion: 1,
      status: 'error',
      queriedAt: new Date().toISOString(),
      bundleId: options.bundleId ?? null,
      requestedVersion: options.version ?? null,
      requestedBuildNumber: options.buildNumber ?? null,
      build: null,
      betaGroups: {
        querySucceeded: false,
        externalGroupCount: null,
        publicLinkEnabledGroupCount: null,
      },
      publicLinks: [],
      warnings: [],
      error: publicError(error),
    };
  }
  await writeResult(output, result);
  process.stdout.write(`Wrote public TestFlight status to ${output}.\n`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main().catch((error) => {
    process.stderr.write(`ci_testflight_status failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}
