#!/usr/bin/env node

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { createAppStoreConnectToken } from './ci_testflight_status.mjs';

const API_ORIGIN = 'https://api.appstoreconnect.apple.com';
const MAX_REPORTS = 5;
const MAX_FRAMES = 15;
const EXCEPTION_TYPES = new Set([
  'EXC_ARITHMETIC',
  'EXC_BAD_ACCESS',
  'EXC_BAD_INSTRUCTION',
  'EXC_BREAKPOINT',
  'EXC_CORPSE_NOTIFY',
  'EXC_CRASH',
  'EXC_GUARD',
  'EXC_MACH_SYSCALL',
  'EXC_RESOURCE',
  'EXC_RPC_ALERT',
  'EXC_SIMULATED',
  'EXC_SOFTWARE',
  'EXC_SYSCALL',
]);
const SIGNALS = new Set([
  'SIGABRT',
  'SIGBUS',
  'SIGFPE',
  'SIGILL',
  'SIGKILL',
  'SIGPIPE',
  'SIGQUIT',
  'SIGSEGV',
  'SIGSYS',
  'SIGTERM',
  'SIGTRAP',
  'SIGXCPU',
  'SIGXFSZ',
]);
const SAFE_IMAGES = [
  /^Runner$/,
  /^App$/,
  /^Flutter(?:MacOS)?$/,
  /^Impeller$/,
  /^Metal(?:Kit)?$/,
  /^AGX[A-Za-z0-9_.+-]*$/,
  /^IOGPU[A-Za-z0-9_.+-]*$/,
  /^libsystem_[A-Za-z0-9_.+-]+$/,
  /^libobjc[A-Za-z0-9_.+-]*$/,
  /^libdispatch[A-Za-z0-9_.+-]*$/,
  /^libswift[A-Za-z0-9_.+-]*$/,
  /^(?:CoreFoundation|Foundation|UIKitCore|SwiftUI|QuartzCore|CoreAnimation)$/,
];
const LIMITATIONS = [
  'ONLY_USER_SUBMITTED_TESTFLIGHT_CRASH_FEEDBACK',
  'EMPTY_FEEDBACK_DOES_NOT_PROVE_NO_CRASHES',
  'RAW_CRASH_LOGS_ARE_NOT_STORED',
];

class AppStoreConnectError extends Error {
  constructor(status, code) {
    super(`App Store Connect request failed with HTTP ${status}.`);
    this.name = 'AppStoreConnectError';
    this.status = status;
    this.code = code;
  }
}

function parseArguments(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === '--self-test') {
      options.selfTest = true;
      continue;
    }
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for ${argv[index]}.`);
    }
    switch (argv[index]) {
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
      default:
        throw new Error(`Unknown argument: ${argv[index]}`);
    }
    index += 1;
  }
  return options;
}

function requireNonEmpty(value, label) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${label} is required.`);
  }
  return value.trim();
}

function safeAttribute(value, maximum) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (
    trimmed.length === 0 ||
    trimmed.length > maximum ||
    !/^[A-Za-z0-9 .,_()+/-]+$/.test(trimmed)
  ) {
    return null;
  }
  return trimmed;
}

function safeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function safeEnum(value, allowed) {
  return typeof value === 'string' && allowed.has(value) ? value : null;
}

function safeImage(value) {
  if (typeof value !== 'string' || value.length > 80) return null;
  return SAFE_IMAGES.some((pattern) => pattern.test(value)) ? value : null;
}

function safeSymbol(value) {
  if (typeof value !== 'string') return null;
  const withoutOffset = value.replace(/\s+\+\s+\d+\s*$/, '').trim();
  if (
    withoutOffset.length === 0 ||
    withoutOffset.length > 160 ||
    !/^[A-Za-z0-9_.$:+<>()\[\],?~ -]+$/.test(withoutOffset) ||
    /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/.test(withoutOffset)
  ) {
    return null;
  }
  return withoutOffset;
}

function classificationFlags(logText) {
  const lower = logText.toLowerCase();
  return {
    memory:
      /\bjetsam\b|out of memory|memory pressure|resource_type_memory|highwater/.test(
        lower,
      ),
    impeller: /\bimpeller\b/.test(lower),
    metal: /\bmetal\b|\bagx[a-z0-9_.+-]*\b|\biogpu\b/.test(lower),
    shader: /\bshader\b|fragment function|vertex function|pipeline state/.test(lower),
    abort: /\bsigabrt\b|\babort(?:ed)?\b/.test(lower),
    watchdog: /\bwatchdog\b|0x8badf00d|frontboard/.test(lower),
  };
}

function exceptionFromText(logText) {
  const exception = logText.match(/Exception Type:\s*([A-Z][A-Z0-9_]{0,31})/);
  const signal = logText.match(
    /(?:Termination Signal|Signal):\s*([A-Z][A-Z0-9_]{0,15})/,
  ) ?? logText.match(/Exception Type:[^\n]*\(([A-Z][A-Z0-9_]{0,15})\)/);
  return {
    exceptionType: safeEnum(exception?.[1], EXCEPTION_TYPES),
    signal: safeEnum(signal?.[1], SIGNALS),
  };
}

function framesFromText(logText) {
  const lines = logText.split(/\r?\n/);
  const heading = lines.findIndex((line) => /^Thread \d+ Crashed:/.test(line));
  if (heading < 0) return [];
  const frames = [];
  for (const line of lines.slice(heading + 1)) {
    if (/^Thread \d+/.test(line) || (line.trim() === '' && frames.length > 0)) {
      break;
    }
    const match = line.match(
      /^\s*\d+\s+(\S+)\s+(?:0x[0-9a-fA-F]+\s+)?(.+?)(?:\s+\+\s+\d+)?\s*$/,
    );
    if (!match) continue;
    const image = safeImage(match[1]);
    const symbol = safeSymbol(match[2]);
    if (image && symbol) frames.push({ image, symbol });
    if (frames.length >= MAX_FRAMES) break;
  }
  return frames;
}

function findEnumInJson(value, keys, allowed) {
  if (!value || typeof value !== 'object') return null;
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findEnumInJson(item, keys, allowed);
      if (found) return found;
    }
    return null;
  }
  for (const [key, child] of Object.entries(value)) {
    if (keys.has(key) && safeEnum(child, allowed)) return child;
  }
  for (const child of Object.values(value)) {
    const found = findEnumInJson(child, keys, allowed);
    if (found) return found;
  }
  return null;
}

function framesFromJson(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return [];
  const images = Array.isArray(value.usedImages) ? value.usedImages : [];
  const threads = Array.isArray(value.threads) ? value.threads : [];
  const faultingIndex = Number.isSafeInteger(value.faultingThread)
    ? value.faultingThread
    : null;
  const crashedThread =
    threads.find((thread) => thread?.triggered === true) ??
    (faultingIndex !== null ? threads[faultingIndex] : null) ??
    value.crashedThread;
  const rawFrames = Array.isArray(crashedThread?.frames)
    ? crashedThread.frames
    : [];
  const frames = [];
  for (const frame of rawFrames) {
    if (!frame || typeof frame !== 'object') continue;
    const indexedImage = Number.isSafeInteger(frame.imageIndex)
      ? images[frame.imageIndex]?.name
      : null;
    const image = safeImage(
      frame.imageName ?? frame.image ?? frame.binary ?? frame.binaryName ?? indexedImage,
    );
    const symbol = safeSymbol(frame.symbolName ?? frame.symbol);
    if (image && symbol) frames.push({ image, symbol });
    if (frames.length >= MAX_FRAMES) break;
  }
  return frames;
}

function parseJsonCrash(logText) {
  try {
    return JSON.parse(logText);
  } catch {
    // Apple .ips text commonly contains a JSON header followed by a JSON report.
  }
  for (const line of logText.split(/\r?\n/).slice(0, 4).reverse()) {
    try {
      const candidate = JSON.parse(line);
      if (candidate && typeof candidate === 'object' && !Array.isArray(candidate)) {
        return candidate;
      }
    } catch {
      // Continue until a structured report line is found.
    }
  }
  return null;
}

export function summarizeCrashLog(logText) {
  const flags = classificationFlags(logText);
  const parsed = parseJsonCrash(logText);
  const textException = exceptionFromText(logText);
  return {
    exceptionType:
      findEnumInJson(
        parsed,
        new Set(['exceptionType', 'exception_type', 'type']),
        EXCEPTION_TYPES,
      ) ?? textException.exceptionType,
    signal:
      findEnumInJson(parsed, new Set(['signal']), SIGNALS) ?? textException.signal,
    classification: flags,
    frames: parsed ? framesFromJson(parsed) : framesFromText(logText),
  };
}

async function apiGet(token, endpoint, query = {}) {
  const url = new URL(endpoint, API_ORIGIN);
  if (url.origin !== API_ORIGIN) {
    throw new Error('Refusing to query a non-App Store Connect origin.');
  }
  for (const [name, value] of Object.entries(query)) {
    url.searchParams.set(name, String(value));
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
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
        const candidate = body?.errors?.[0]?.code;
        if (typeof candidate === 'string' && /^[A-Z0-9_.-]{1,80}$/.test(candidate)) {
          code = candidate;
        }
      } catch {
        // Arbitrary response bodies are intentionally discarded.
      }
      throw new AppStoreConnectError(response.status, code);
    }
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

function publicError(error) {
  if (error instanceof AppStoreConnectError) {
    return {
      kind: 'app_store_connect_api',
      httpStatus: error.status,
      code: error.code,
    };
  }
  if (error?.name === 'AbortError') return { kind: 'network_timeout' };
  return { kind: 'query_failed' };
}

function baseResult(bundleId, version, buildNumber) {
  return {
    schemaVersion: 1,
    status: 'ok',
    queriedAt: new Date().toISOString(),
    bundleId,
    requestedVersion: version,
    requestedBuildNumber: buildNumber,
    build: { found: false },
    crashFeedback: {
      feedbackCount: null,
      reportsAnalyzed: 0,
      reportLimit: MAX_REPORTS,
      reports: [],
    },
    limitations: LIMITATIONS,
    warnings: [],
  };
}

function crashLogText(document) {
  const value = document?.data?.attributes?.logText;
  return typeof value === 'string' ? value : null;
}

async function queryCrashes(options) {
  const issuerId = requireNonEmpty(
    process.env.APPSTORE_ISSUER_ID,
    'APPSTORE_ISSUER_ID',
  );
  const keyId = requireNonEmpty(process.env.APPSTORE_KEY_ID, 'APPSTORE_KEY_ID');
  const privateKey = await readFile(
    requireNonEmpty(options.privateKeyFile, '--private-key-file'),
    'utf8',
  );
  const bundleId = requireNonEmpty(options.bundleId, '--bundle-id');
  const version = requireNonEmpty(options.version, '--version');
  const buildNumber = requireNonEmpty(options.buildNumber, '--build-number');
  const result = baseResult(bundleId, version, buildNumber);
  const token = createAppStoreConnectToken({ issuerId, keyId, privateKey });

  const apps = await apiGet(token, '/v1/apps', {
    'filter[bundleId]': bundleId,
    'fields[apps]': 'bundleId',
    limit: 2,
  });
  if (!Array.isArray(apps.data) || apps.data.length !== 1) {
    result.status = 'partial';
    result.warnings.push('APP_NOT_FOUND');
    return result;
  }
  const appId = apps.data[0].id;
  const builds = await apiGet(token, '/v1/builds', {
    'filter[app]': appId,
    'filter[version]': buildNumber,
    'filter[preReleaseVersion.platform]': 'IOS',
    'fields[builds]': 'version,preReleaseVersion',
    include: 'preReleaseVersion',
    'fields[preReleaseVersions]': 'version,platform',
    limit: 10,
  });
  const build = Array.isArray(builds.data)
    ? builds.data.find((item) => item?.attributes?.version === buildNumber)
    : null;
  const included = Array.isArray(builds.included) ? builds.included : [];
  const preReleaseId = build?.relationships?.preReleaseVersion?.data?.id;
  const actualVersion = included.find(
    (item) => item?.type === 'preReleaseVersions' && item.id === preReleaseId,
  )?.attributes?.version;
  if (!build || actualVersion !== version) {
    result.status = 'partial';
    result.warnings.push(build ? 'VERSION_MISMATCH' : 'BUILD_NOT_FOUND');
    return result;
  }
  result.build = { found: true, version: actualVersion, buildNumber };

  const feedback = await apiGet(
    token,
    `/v1/apps/${encodeURIComponent(appId)}/betaFeedbackCrashSubmissions`,
    {
      'filter[build]': build.id,
      'filter[appPlatform]': 'IOS',
      sort: '-createdDate',
      limit: 20,
      'fields[betaFeedbackCrashSubmissions]':
        'deviceModel,osVersion,architecture,appUptimeInMilliseconds,buildBundleId,crashLog,build',
    },
  );
  const submissions = Array.isArray(feedback.data) ? feedback.data : [];
  const total = feedback?.meta?.paging?.total;
  result.crashFeedback.feedbackCount =
    Number.isSafeInteger(total) && total >= submissions.length
      ? total
      : submissions.length;

  const selected = submissions.slice(0, MAX_REPORTS);
  const reports = await Promise.all(
    selected.map(async (submission) => {
      const attributes = submission?.attributes ?? {};
      const report = {
        osVersion: safeAttribute(attributes.osVersion, 40),
        deviceModel: safeAttribute(attributes.deviceModel, 80),
        uptimeMilliseconds: safeInteger(attributes.appUptimeInMilliseconds),
        logAnalyzed: false,
        exceptionType: null,
        signal: null,
        classification: null,
        frames: [],
      };
      if (typeof submission?.id !== 'string' || !/^[A-Za-z0-9-]{1,80}$/.test(submission.id)) {
        result.warnings.push('INVALID_CRASH_SUBMISSION_ID');
        return report;
      }
      try {
        const logDocument = await apiGet(
          token,
          `/v1/betaFeedbackCrashSubmissions/${encodeURIComponent(submission.id)}/crashLog`,
          { 'fields[betaCrashLogs]': 'logText' },
        );
        const logText = crashLogText(logDocument);
        if (logText === null) {
          result.warnings.push('CRASH_LOG_NOT_AVAILABLE');
          return report;
        }
        const summary = summarizeCrashLog(logText);
        return { ...report, logAnalyzed: true, ...summary };
      } catch {
        result.warnings.push('CRASH_LOG_QUERY_FAILED');
        return report;
      }
    }),
  );
  result.crashFeedback.reports = reports;
  result.crashFeedback.reportsAnalyzed = reports.filter(
    (report) => report.logAnalyzed,
  ).length;
  if (result.warnings.length > 0) result.status = 'partial';
  return result;
}

async function writeResult(output, result) {
  await mkdir(path.dirname(output), { recursive: true });
  await writeFile(output, `${JSON.stringify(result, null, 2)}\n`, { mode: 0o644 });
}

async function runSelfTest() {
  const privateData = [
    'tester@example.com',
    '/Users/tester/private/project',
    'https://private.invalid/crash?token=secret',
    'device-id-123',
  ].join(' ');
  const textLog = `
Exception Type:  EXC_BAD_ACCESS
Termination Signal: SIGSEGV
Thread 0 Crashed:
0   Runner  0x0000000100000000 renderScene + 42
1   Flutter 0x0000000200000000 impeller::Renderer::Render + 8
2   EvilImage 0x0000000300000000 ${privateData} + 1
Metal shader pipeline state watchdog ${privateData}
`;
  const summary = summarizeCrashLog(textLog);
  if (
    summary.exceptionType !== 'EXC_BAD_ACCESS' ||
    summary.signal !== 'SIGSEGV' ||
    summary.frames.length !== 2 ||
    !summary.classification.impeller ||
    !summary.classification.metal ||
    !summary.classification.shader ||
    !summary.classification.watchdog
  ) {
    throw new Error('Traditional crash-log summarization self-test failed.');
  }

  const jsonLog = JSON.stringify({
    exceptionType: 'EXC_CRASH',
    signal: 'SIGABRT',
    crashedThread: {
      frames: [
        { imageName: 'Runner', symbolName: 'AppCoordinator.start()' },
        { imageName: 'UnknownPrivateImage', symbolName: privateData },
      ],
    },
    privateData,
  });
  const jsonSummary = summarizeCrashLog(jsonLog);
  const serialized = JSON.stringify({ summary, jsonSummary });
  if (
    jsonSummary.exceptionType !== 'EXC_CRASH' ||
    jsonSummary.signal !== 'SIGABRT' ||
    jsonSummary.frames.length !== 1 ||
    privateData.split(' ').some((value) => serialized.includes(value))
  ) {
    throw new Error('JSON crash-log privacy self-test failed.');
  }
  process.stdout.write('ci_testflight_crashes privacy self-test passed.\n');
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.selfTest) {
    await runSelfTest();
    return;
  }
  const output = requireNonEmpty(options.output, '--output');
  let result;
  let failed = false;
  try {
    result = await queryCrashes(options);
  } catch (error) {
    failed = true;
    result = {
      ...baseResult(
        options.bundleId ?? null,
        options.version ?? null,
        options.buildNumber ?? null,
      ),
      status: 'error',
      error: publicError(error),
    };
  }
  await writeResult(output, result);
  process.stdout.write(`Wrote public TestFlight crash summary to ${output}.\n`);
  if (failed) process.exitCode = 1;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main().catch((error) => {
    process.stderr.write(`ci_testflight_crashes failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}
