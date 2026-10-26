// The local API exposes run states, but no run timing or billing information.
export const ACTIVE_RUNS = new Set(['queued', 'running', 'stopping']);
const ACTIVE_MEDIA = new Set(['submitting', 'pending', 'processing', 'running', 'queued']);
const STATES = {
  queued: ['排队中', 'blue'], running: ['运行中', 'blue'], stopping: ['停止中', 'amber'],
  stopped: ['已停止', ''], completed: ['已完成', 'green'], failed: ['失败', 'red'],
  submitting: ['提交中', 'blue'], pending: ['等待中', 'blue'], processing: ['生成中', 'blue'],
  unknown: ['结果未知', 'amber'], empty: ['暂无运行', ''], unreadable: ['读取失败', 'amber'],
};

export function statusLabel(status) {
  return STATES[status] ?? [status || '未知', ''];
}

export function mediaStatus(job) {
  if (job.ingestionState === 'failed') return ['保存失败', 'red'];
  if (job.state === 'completed' && job.ingestionState === 'pending') return ['保存中', 'blue'];
  return statusLabel(job.state);
}

export function taskCounts(snapshot) {
  const runs = snapshot?.runs ?? [];
  const media = snapshot?.mediaJobs ?? [];
  return {
    active: runs.filter(run => ACTIVE_RUNS.has(run.state)).length + media.filter(job =>
      ACTIVE_MEDIA.has(job.state) || (job.state === 'completed' && job.ingestionState === 'pending')).length,
    failed: runs.filter(run => run.state === 'failed').length + media.filter(job =>
      job.state === 'failed' || job.ingestionState === 'failed').length,
    unknown: media.filter(job => job.state === 'unknown').length,
  };
}

export function latestRun(snapshot) {
  return snapshot ? (snapshot.runs?.at(-1)?.state ?? 'empty') : 'unreadable';
}

// Revisions prevent slow polling responses from rolling back a newer detail read.
export function shouldReplaceSnapshot(current, incoming, currentOrder = 0, incomingOrder = 0) {
  if (!current) return true;
  for (const [left, right] of [
    [current.session?.revision ?? 0, incoming.session?.revision ?? 0],
    [current.lastSeq ?? 0, incoming.lastSeq ?? 0],
  ]) {
    if (right !== left) return right > left;
  }
  return incomingOrder >= currentOrder;
}

export function ownedMediaPath(value) {
  return typeof value === 'string' && /^\/api_agent\/v2\/assets\/[0-9a-f-]{36}\/(content|poster)$/i.test(value) ? value : null;
}

export function formatBytes(value) {
  if (!Number.isFinite(value) || value < 0) return '大小未知';
  if (value < 1024) return `${value} B`;
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`;
  return `${(value / (1024 * 1024)).toFixed(1)} MB`;
}
