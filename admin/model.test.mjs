import test from 'node:test';
import assert from 'node:assert/strict';
import { taskCounts, mediaStatus, latestRun, ownedMediaPath, shouldReplaceSnapshot } from './public/model.mjs';

test('running media stays active after text completes, including asset ingestion', () => {
  assert.deepEqual(taskCounts({ runs: [{ state: 'completed' }], mediaJobs: [
    { state: 'pending' }, { state: 'completed', ingestionState: 'pending' },
    { state: 'completed', ingestionState: 'completed' }, { state: 'unknown' },
  ] }), { active: 2, failed: 0, unknown: 1 });
  assert.deepEqual(mediaStatus({ state: 'completed', ingestionState: 'pending' }), ['保存中', 'blue']);
});

test('failed generation and failed ingestion are counted once per media task', () => {
  assert.deepEqual(taskCounts({ runs: [{ state: 'failed' }, { state: 'stopped' }], mediaJobs: [
    { state: 'failed', ingestionState: 'failed' }, { state: 'completed', ingestionState: 'failed' },
  ] }), { active: 0, failed: 3, unknown: 0 });
  assert.deepEqual(mediaStatus({ state: 'completed', ingestionState: 'failed' }), ['保存失败', 'red']);
});

test('missing snapshots are distinguishable from empty histories', () => {
  assert.equal(latestRun(undefined), 'unreadable');
  assert.equal(latestRun({ runs: [] }), 'empty');
  assert.equal(latestRun({ runs: [{ state: 'running' }] }), 'running');
});

test('media previews accept only owned relative API content and poster paths', () => {
  const url = '/api_agent/v2/assets/abcdef01-1234-1234-1234-123456789012/content';
  assert.equal(ownedMediaPath(url), url);
  for (const value of [`https://example.com${url}`, `//localhost${url}`, `${url}?token=secret`, 'javascript:alert(1)', '/health']) {
    assert.equal(ownedMediaPath(value), null);
  }
});

test('a delayed poll cannot replace newer detail data, including equal-revision media updates', () => {
  const current = { session: { revision: 4 }, lastSeq: 9 };
  assert.equal(shouldReplaceSnapshot(current, { session: { revision: 3 }, lastSeq: 8 }, 10, 11), false);
  assert.equal(shouldReplaceSnapshot(current, { session: { revision: 4 }, lastSeq: 8 }, 10, 11), false);
  assert.equal(shouldReplaceSnapshot(current, current, 10, 9), false);
  assert.equal(shouldReplaceSnapshot(current, current, 10, 11), true);
  assert.equal(shouldReplaceSnapshot(current, { session: { revision: 5 }, lastSeq: 10 }, 10, 9), true);
});
