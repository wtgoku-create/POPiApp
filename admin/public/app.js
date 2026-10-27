import { statusLabel, mediaStatus, taskCounts, latestRun, ownedMediaPath, formatBytes, shouldReplaceSnapshot } from './model.mjs';

const $ = id => document.getElementById(id);
const state = {
  sessions: [], snapshots: new Map(), assets: [], page: 1, pageInfo: null, assetPage: 1,
  health: null, capabilities: null, totalSessions: null, loaded: false, online: false,
  lastUpdated: null, stale: false, selected: null, action: null, mutationBusy: false,
  refreshController: null, generation: 0, assetSignature: null,
  committedQuery: { page: 1, archive: 'all' }, snapshotOrders: new Map(), snapshotOrder: 0,
  staleSnapshots: new Set(),
};
const PAGE_SIZE = 20;
const ASSET_PAGE_SIZE = 12;
const titles = {
  overview: ['运行总览', '看清本机服务与创作任务的当前状态。'],
  sessions: ['会话与任务', '检查运行记录，处理本机联调中的会话。'],
  assets: ['素材库', '查看本机已保存的生成结果与上传素材。'],
};

// All API text is inserted as text nodes, including model output and error messages.
function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = String(text);
  return node;
}

function badge(label, color = '') {
  const node = element('span', `badge ${color}`);
  node.append(element('span', 'status-dot'), document.createTextNode(label));
  return node;
}

function toast(message, error = false) {
  const node = element('div', `toast${error ? ' error' : ''}`, message);
  $('toasts').append(node);
  setTimeout(() => node.remove(), 5500);
}

function formatDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? '—' : new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false,
  }).format(date);
}

async function request(path, options = {}) {
  const response = await fetch(path, { cache: 'no-store', ...options });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error?.message || `请求失败（${response.status}）`);
  return payload;
}

function updateConnection() {
  const connected = state.online;
  for (const id of ['connection-dot', 'sidebar-status']) $(id).className = `status-dot ${connected ? 'online' : 'offline'}`;
  $('connection-label').textContent = connected ? 'Agent 服务已连接' : 'Agent 服务未连接';
  $('last-updated').textContent = state.lastUpdated
    ? `${state.stale ? '部分数据未同步 · ' : ''}上次同步 ${formatDate(state.lastUpdated)}`
    : '尚未同步';
}

function serviceCard(title, label, color, description) {
  const card = element('article', 'service-card');
  const header = element('header');
  header.append(element('h3', '', title), badge(label, color));
  card.append(header, element('p', 'service-description', description));
  return card;
}

function renderOverview() {
  const readable = state.sessions.map(session => state.snapshots.get(session.id)).filter(Boolean);
  const counts = readable.map(taskCounts);
  const incomplete = readable.length !== state.sessions.length || state.stale;
  const metrics = {
    sessions: state.totalSessions,
    running: state.loaded ? counts.reduce((total, item) => total + item.active, 0) : null,
    failed: state.loaded ? counts.reduce((total, item) => total + item.failed, 0) : null,
    assets: state.assetsLoaded ? state.assets.length : null,
  };
  for (const [key, value] of Object.entries(metrics)) {
    $(`metric-${key}`).classList.remove('skeleton');
    $(`metric-${key}`).textContent = value === null ? '—' : `${value}${incomplete && ['running', 'failed'].includes(key) ? '*' : ''}`;
  }
  const cap = state.capabilities;
  const configured = state.online && state.health?.configured;
  const multimodal = cap?.multimodal;
  const mediaReady = state.online && multimodal?.configured && multimodal?.authenticated &&
    multimodal?.dshToolsBound && multimodal?.generationEnabled !== false && multimodal?.state === 'ready';
  const webReady = state.online && cap?.web?.configured && cap?.web?.dshToolsBound;
  $('services').replaceChildren(
    serviceCard('文字 Agent', state.online ? (configured ? '已配置' : '未配置') : '未连接', configured ? 'green' : '',
      state.health ? `${state.health.model || '未设置模型'} · ${cap?.text?.provider || '本机 Harness'}` : '等待本机服务响应'),
    serviceCard('多模态生成', state.online ? (mediaReady ? '已就绪' : cap ? '待检查' : '状态未知') : '未连接', mediaReady ? 'green' : 'amber',
      multimodal ? `${multimodal.provider || '媒体服务'} · ${multimodal.modelCount ?? '—'} 个模型 · ${multimodal.state || '未知状态'}` : '等待能力配置'),
    serviceCard('联网工具', state.online ? (webReady ? '已绑定' : cap ? '未就绪' : '状态未知') : '未连接', webReady ? 'green' : '',
      cap?.web ? (cap.web.tools?.join(' / ') || '暂未绑定搜索与网页工具') : '等待能力配置'),
  );
  $('service-version').textContent = state.health ? `Harness ${state.health.version || '—'}` : '实时读取 /health 与 capabilities';
  const unknown = counts.reduce((total, item) => total + item.unknown, 0);
  $('overview-scope').textContent = `任务统计：当前第 ${state.committedQuery.page} 页的 ${state.sessions.length} 个会话（含历史任务）${incomplete ? '，部分数据未同步，带 * 数字含可用缓存' : ''}。${unknown ? `另有 ${unknown} 个媒体任务结果未知。` : ''}素材数量来自整个本机素材库。`;
  renderSessionRows($('recent-sessions'), state.sessions.slice(0, 6));
}

function renderSessionRows(target, sessions) {
  if (!sessions.length) {
    const row = element('tr');
    const cell = element('td', 'empty', state.loaded ? '这里还没有会话，或当前筛选没有匹配项。' : '等待会话数据…');
    cell.colSpan = 5;
    row.append(cell);
    target.replaceChildren(row);
    return;
  }
  const rows = sessions.map(session => {
    const row = element('tr');
    const name = element('td');
    const open = element('button', 'session-title', session.title || '未命名会话');
    open.type = 'button';
    open.addEventListener('click', () => openSession(session.id));
    name.append(open, element('span', 'session-id', session.id.slice(0, 8)));
    if (session.archived || session.pinned) {
      const labels = element('span', 'session-labels');
      if (session.archived) labels.append(badge('已归档'));
      if (session.pinned) labels.append(badge('已置顶'));
      name.append(labels);
    }
    const snapshot = state.snapshots.get(session.id);
    const run = element('td');
    run.append(badge(...statusLabel(latestRun(snapshot))));
    if (state.staleSnapshots.has(session.id) && snapshot) run.append(document.createTextNode(' · 缓存'));
    const media = element('td');
    const jobs = snapshot?.mediaJobs ?? [];
    if (!snapshot) media.textContent = '未读取';
    else if (!jobs.length) media.textContent = '—';
    else {
      const counts = taskCounts({ mediaJobs: jobs });
      media.append(badge(counts.failed ? `${counts.failed} 个失败` : counts.active ? `${counts.active} 个进行中` : counts.unknown ? `${counts.unknown} 个结果未知` : `${jobs.length} 个已结束`, counts.failed ? 'red' : counts.active ? 'blue' : counts.unknown ? 'amber' : ''));
    }
    const updated = element('td', '', formatDate(session.updatedAt));
    const action = element('td');
    const detail = element('button', 'row-action', '查看 ↗');
    detail.type = 'button';
    detail.setAttribute('aria-label', `查看 ${session.title || session.id}`);
    detail.addEventListener('click', () => openSession(session.id));
    action.append(detail);
    row.append(name, run, media, updated, action);
    return row;
  });
  target.replaceChildren(...rows);
}

function renderSessions() {
  const search = $('session-search').value.trim().toLowerCase();
  const filter = $('session-filter').value;
  const sessions = state.sessions.filter(session => {
    if (search && !`${session.title} ${session.id}`.toLowerCase().includes(search)) return false;
    const counts = taskCounts(state.snapshots.get(session.id));
    return filter === 'all' || (filter === 'active' && counts.active > 0) || (filter === 'failed' && counts.failed > 0);
  });
  renderSessionRows($('session-list'), sessions);
  const info = state.pageInfo;
  $('session-page-label').textContent = info ? `第 ${state.committedQuery.page} / ${Math.max(1, info.pageCount)} 页 · ${info.total} 个会话 · 本页匹配 ${sessions.length} 个` : '尚未读取会话';
  $('session-prev').disabled = state.page <= 1 || !info;
  $('session-next').disabled = !info || state.page >= info.pageCount;
}

function assetKind(asset) {
  return ({ image: '图片', video: '视频', audio: '音频', script: '脚本', text: '脚本' })[asset.kind] || asset.kind || '文件';
}

function renderAssets() {
  const search = $('asset-search').value.trim().toLowerCase();
  const kind = $('asset-filter').value;
  const filtered = state.assets.filter(asset => (kind === 'all' || asset.kind === kind || (kind === 'script' && asset.kind === 'text')) &&
    (!search || `${asset.title || ''} ${asset.id}`.toLowerCase().includes(search)));
  const pageCount = Math.max(1, Math.ceil(filtered.length / ASSET_PAGE_SIZE));
  state.assetPage = Math.min(state.assetPage, pageCount);
  const assets = filtered.slice((state.assetPage - 1) * ASSET_PAGE_SIZE, state.assetPage * ASSET_PAGE_SIZE);
  // Keep video/audio elements alive during polling so playback and seeking continue.
  const signature = JSON.stringify({ page: state.assetPage, search, kind, loaded: state.assetsLoaded, assets });
  if (signature !== state.assetSignature) {
    state.assetSignature = signature;
    const cards = assets.map(asset => {
      const card = element('article', 'asset-card');
      const preview = element('div', 'asset-preview');
      const url = ownedMediaPath(asset.contentUrl);
      const poster = ownedMediaPath(asset.posterUrl);
      const fallback = () => preview.replaceChildren(element('span', 'asset-placeholder', asset.kind === 'video' ? '▷' : asset.kind === 'audio' ? '♪' : '▧'));
      fallback();
      if (url && (asset.kind === 'image' || asset.kind === 'video')) {
        const media = element(asset.kind === 'image' ? 'img' : 'video');
        if (asset.kind === 'image') {
          media.loading = 'lazy';
          media.alt = asset.title || '本机图片';
        } else {
          media.controls = true;
          media.preload = 'none';
          media.playsInline = true;
          media.setAttribute('aria-label', asset.title || '本机视频');
          if (poster) media.poster = poster;
        }
        media.addEventListener('error', fallback, { once: true });
        media.src = url;
        preview.replaceChildren(media);
      }
      const info = element('div', 'asset-info');
      const title = element('h3', '', asset.title || asset.id);
      title.title = asset.title || asset.id;
      info.append(title, badge(assetKind(asset)), element('p', 'asset-meta', `${formatBytes(asset.sizeBytes)} · ${formatDate(asset.createdAt)}`));
      const actions = element('div', 'asset-actions');
      if (url) {
        if (asset.kind === 'audio') {
          const audio = element('audio');
          audio.controls = true;
          audio.preload = 'none';
          audio.src = url;
          audio.setAttribute('aria-label', asset.title || '本机音频');
          info.append(audio);
        }
        const download = element('a', 'text-link', '下载文件 ↓');
        download.href = url;
        download.download = asset.title || asset.id;
        actions.append(download);
      }
      if (asset.sessionId) {
        const session = element('button', 'row-action', '所属会话 ↗');
        session.addEventListener('click', () => openSession(asset.sessionId));
        actions.append(session);
      }
      info.append(actions);
      card.append(preview, info);
      return card;
    });
    $('asset-grid').replaceChildren(...(cards.length ? cards : [element('div', 'empty', state.assetsLoaded ? '暂无匹配的素材。' : '等待素材数据…')]));
  }
  $('asset-page-label').textContent = `${filtered.length} 个素材 · 第 ${state.assetPage} / ${pageCount} 页`;
  $('asset-prev').disabled = state.assetPage <= 1;
  $('asset-next').disabled = state.assetPage >= pageCount;
}

async function refresh({ manual = false, force = false } = {}) {
  if (state.refreshController && !force) return;
  state.refreshController?.abort();
  const controller = new AbortController();
  const generation = ++state.generation;
  state.refreshController = controller;
  $('refresh').disabled = true;
  const archive = $('archive-filter').value;
  const query = new URLSearchParams({ page: state.page, pageSize: PAGE_SIZE });
  if (archive !== 'all') query.set('archived', archive);
  const get = path => request(path, { signal: controller.signal });
  try {
    const results = await Promise.allSettled([
      get('/health'), get('/api_agent/v2/capabilities'),
      get(`/api_agent/v2/sessions?${query}`), get('/api_agent/v2/assets'),
      archive === 'all' ? Promise.resolve(null) : get('/api_agent/v2/sessions?page=1&pageSize=1'),
    ]);
    if (generation !== state.generation || controller.signal.aborted) return;
    const [health, capabilities, sessions, assets, total] = results;
    state.online = health.status === 'fulfilled';
    state.stale = results.some(result => result.status === 'rejected');
    if (state.online) state.health = health.value;
    state.capabilities = capabilities.status === 'fulfilled' ? capabilities.value : null;
    if (assets.status === 'fulfilled') {
      state.assets = [...(assets.value.list ?? [])].sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
      state.assetsLoaded = true;
    }
    if (sessions.status === 'fulfilled') {
      const info = sessions.value.pageInfo;
      if (state.page > Math.max(1, info.pageCount)) {
        state.page = Math.max(1, info.pageCount);
        state.refreshController = null;
        return refresh({ force: true });
      }
      const snapshots = new Map();
      const staleSnapshots = new Set();
      const list = sessions.value.list ?? [];
      // Bound fan-out: local snapshots can contain long message histories.
      for (let offset = 0; offset < list.length; offset += 4) {
        await Promise.all(list.slice(offset, offset + 4).map(async session => {
          const order = ++state.snapshotOrder;
          try {
            snapshots.set(session.id, { snapshot: await get(`/api_agent/v2/sessions/${encodeURIComponent(session.id)}/snapshot`), order });
          } catch (error) {
            if (controller.signal.aborted) throw error;
            state.stale = true;
            staleSnapshots.add(session.id);
          }
        }));
      }
      if (generation !== state.generation || controller.signal.aborted) return;
      state.sessions = list;
      state.pageInfo = info;
      const committedSnapshots = new Map();
      const committedOrders = new Map();
      // Detail reads may complete while this page's snapshots are still in flight.
      for (const id of new Set([...list.map(session => session.id), state.selected].filter(Boolean))) {
        const previous = state.snapshots.get(id);
        const previousOrder = state.snapshotOrders.get(id) ?? 0;
        const candidate = snapshots.get(id);
        const accept = candidate && shouldReplaceSnapshot(previous, candidate.snapshot, previousOrder, candidate.order);
        const snapshot = accept ? candidate.snapshot : previous;
        if (snapshot) {
          committedSnapshots.set(id, snapshot);
          committedOrders.set(id, accept ? candidate.order : previousOrder);
        }
      }
      state.snapshots = committedSnapshots;
      state.snapshotOrders = committedOrders;
      state.staleSnapshots = staleSnapshots;
      state.committedQuery = { page: state.page, archive };
      state.loaded = true;
      if (archive === 'all') state.totalSessions = info.total;
      else if (total.status === 'fulfilled') state.totalSessions = total.value.pageInfo.total;
    } else {
      // A failed page/filter request must keep its previous data scope as well as its rows.
      state.page = state.committedQuery.page;
      $('archive-filter').value = state.committedQuery.archive;
    }
    if (!state.stale) state.lastUpdated = Date.now();
    updateConnection();
    renderOverview();
    renderSessions();
    renderAssets();
    if (state.selected && state.snapshots.has(state.selected) && !$('action-dialog').open) renderDetail(state.snapshots.get(state.selected));
    if (manual && state.stale) toast('部分数据未同步，保留上次读取结果。请检查本机 Agent 服务。', true);
    else if (manual) toast('已刷新');
  } catch (error) {
    if (!controller.signal.aborted) toast(error.message, true);
  } finally {
    if (generation === state.generation) {
      state.refreshController = null;
      $('refresh').disabled = false;
    }
  }
}

function detailSection(title) {
  const section = element('section', 'detail-section');
  section.append(element('h3', '', title));
  return section;
}

function detailLine(label, value) {
  const line = element('div', 'detail-line');
  line.append(element('span', '', label), element('span', '', value ?? '—'));
  return line;
}

function renderDetail(snapshot) {
  const scrollTop = $('detail-body').scrollTop;
  const session = snapshot.session;
  $('detail-title').textContent = session.title || '未命名会话';
  const summary = detailSection('会话信息');
  summary.append(detailLine('会话 ID', session.id), detailLine('最近更新', formatDate(session.updatedAt)),
    detailLine('归档状态', session.archived ? '已归档' : '未归档'), detailLine('配置版本', session.configRevision));
  const runs = detailSection(`文字运行 · ${snapshot.runs?.length ?? 0}`);
  if (!snapshot.runs?.length) runs.append(element('p', 'detail-note', '暂无文字运行记录。'));
  for (const run of [...(snapshot.runs ?? [])].reverse().slice(0, 50)) {
    const record = element('article', 'record');
    const header = element('div', 'record-header');
    header.append(element('span', '', `配置 v${run.configRevision ?? 0}`), badge(...statusLabel(run.state)));
    record.append(header, element('p', 'record-id', run.id));
    if (run.error) record.append(element('p', 'record-error', `${run.error.code || ''} ${run.error.message || ''}`));
    for (const member of run.memberTurns ?? []) {
      record.append(detailLine(member.memberName || member.memberId, statusLabel(member.state)[0]));
      if (member.error) record.append(element('p', 'record-error', `${member.error.code || ''} ${member.error.message || ''}`));
    }
    runs.append(record);
  }
  if ((snapshot.runs?.length ?? 0) > 50) runs.append(element('p', 'detail-note', '仅展示最近 50 条文字运行。'));
  const jobs = detailSection(`媒体任务 · ${snapshot.mediaJobs?.length ?? 0}`);
  if (!snapshot.mediaJobs?.length) jobs.append(element('p', 'detail-note', '暂无媒体任务。'));
  for (const job of [...(snapshot.mediaJobs ?? [])].reverse().slice(0, 50)) {
    const record = element('article', 'record');
    const header = element('div', 'record-header');
    header.append(element('span', '', `${job.operation || '媒体'} · ${job.model || '未提供模型'}`), badge(...mediaStatus(job)));
    record.append(header, element('p', 'record-id', job.jobId), detailLine('已保存素材', job.assetIds?.length ?? 0));
    if (job.error) record.append(element('p', 'record-error', `${job.error.code || ''} ${job.error.message || ''}`));
    jobs.append(record);
  }
  if ((snapshot.mediaJobs?.length ?? 0) > 50) jobs.append(element('p', 'detail-note', '仅展示最近 50 条媒体任务。'));
  const messages = detailSection(`消息记录 · ${snapshot.messages?.length ?? 0}`);
  for (const message of (snapshot.messages ?? []).slice(-30)) {
    const record = element('article', 'record');
    const header = element('div', 'record-header');
    header.append(element('span', '', message.memberName || (message.role === 'user' ? '用户' : 'Agent')), element('span', '', formatDate(message.createdAt)));
    record.append(header, element('p', 'record-copy', message.content || message.text || '（非文本消息）'));
    messages.append(record);
  }
  if ((snapshot.messages?.length ?? 0) > 30) messages.append(element('p', 'detail-note', '仅展示最近 30 条消息。'));
  if (!snapshot.messages?.length) messages.append(element('p', 'detail-note', '暂无消息。'));
  $('detail-body').replaceChildren(summary, runs, jobs, messages);
  $('detail-body').scrollTop = scrollTop;
  $('archive-session').textContent = session.archived ? '取消归档' : '归档';
  const runStates = (snapshot.runs ?? []).map(run => run.state);
  $('stop-session').disabled = !state.online || runStates.includes('stopping') || !runStates.some(value => ['queued', 'running'].includes(value));
  $('rename-session').disabled = !state.online;
  $('archive-session').disabled = !state.online;
}

async function openSession(id) {
  state.selected = id;
  $('detail-title').textContent = '读取会话…';
  $('detail-body').replaceChildren(element('p', 'detail-note', '正在读取服务端快照…'));
  for (const name of ['rename-session', 'archive-session', 'stop-session']) $(name).disabled = true;
  if (!$('detail-dialog').open) $('detail-dialog').showModal();
  const order = ++state.snapshotOrder;
  try {
    const snapshot = await request(`/api_agent/v2/sessions/${encodeURIComponent(id)}/snapshot`);
    if (state.selected !== id) return;
    if (shouldReplaceSnapshot(state.snapshots.get(id), snapshot, state.snapshotOrders.get(id), order)) {
      state.snapshots.set(id, snapshot);
      state.snapshotOrders.set(id, order);
      state.staleSnapshots.delete(id);
    }
    renderDetail(state.snapshots.get(id));
    $('detail-body').scrollTop = 0;
  } catch (error) {
    if (state.selected !== id) return;
    $('detail-dialog').close();
    toast(error.message, true);
  }
}

function prepareAction(kind) {
  const session = state.snapshots.get(state.selected)?.session;
  if (!session || state.mutationBusy) return;
  const archive = !session.archived;
  const title = kind === 'rename' ? '重命名会话' : kind === 'stop' ? '停止文字运行？' : archive ? '归档会话？' : '取消归档？';
  state.action = { kind, id: session.id, archived: archive, requestId: crypto.randomUUID(), signature: null };
  $('action-title').textContent = title;
  $('action-description').textContent = kind === 'rename' ? '修改后，App 中的会话名称也会同步更新。' : kind === 'stop' ? '只停止当前会话的文字运行。已经提交的图片、视频生成任务会继续。' : archive ? '会话将从 App 的常规列表中收起，记录会保留。' : '会话将重新出现在 App 的常规列表中。';
  $('action-input').hidden = kind !== 'rename';
  $('action-input').required = kind === 'rename';
  $('action-input').value = session.title || '';
  $('action-input').setCustomValidity('');
  $('confirm-action').textContent = kind === 'stop' ? '停止运行' : kind === 'rename' ? '保存' : archive ? '归档' : '取消归档';
  $('confirm-action').className = `button primary${kind === 'stop' ? ' danger' : ''}`;
  $('action-dialog').showModal();
  if (kind === 'rename') $('action-input').select();
}

async function submitAction(event) {
  event.preventDefault();
  if (state.mutationBusy || !state.action) return;
  const action = state.action;
  const title = $('action-input').value.trim();
  if (action.kind === 'rename' && !title) {
    $('action-input').setCustomValidity('请输入会话名称');
    $('action-input').reportValidity();
    return;
  }
  const body = action.kind === 'rename' ? { title } : action.kind === 'archive' ? { archived: action.archived } : {};
  // Keep the same request ID after a failed/unknown response; changed input gets a new ID.
  const signature = JSON.stringify(body);
  if (action.signature !== null && action.signature !== signature) action.requestId = crypto.randomUUID();
  action.signature = signature;
  body.clientRequestId = action.requestId;
  const label = $('confirm-action').textContent;
  state.mutationBusy = true;
  $('confirm-action').disabled = true;
  $('cancel-action').disabled = true;
  $('confirm-action').textContent = '处理中…';
  try {
    await request(`/api_agent/v2/sessions/${action.id}${action.kind === 'stop' ? '/stop' : ''}`, {
      method: action.kind === 'stop' ? 'POST' : 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    $('action-dialog').close();
    toast(action.kind === 'stop' ? '已提交停止请求' : '会话已更新');
    if (state.selected === action.id) await openSession(action.id);
    await refresh({ force: true });
  } catch (error) {
    toast(error.message, true);
  } finally {
    state.mutationBusy = false;
    $('confirm-action').disabled = false;
    $('cancel-action').disabled = false;
    $('confirm-action').textContent = label;
  }
}

function navigate() {
  const view = Object.hasOwn(titles, location.hash.slice(1)) ? location.hash.slice(1) : 'overview';
  document.querySelectorAll('[data-page]').forEach(node => { node.hidden = node.dataset.page !== view; });
  document.querySelectorAll('[data-view]').forEach(node => {
    node.classList.toggle('active', node.dataset.view === view);
    if (node.dataset.view === view) node.setAttribute('aria-current', 'page');
    else node.removeAttribute('aria-current');
  });
  $('page-title').textContent = titles[view][0];
  $('page-description').textContent = titles[view][1];
  document.title = `${titles[view][0]} · POPi 本机管理台`;
  window.scrollTo(0, 0);
}

$('refresh').addEventListener('click', () => refresh({ manual: true }));
$('session-search').addEventListener('input', renderSessions);
$('session-filter').addEventListener('change', renderSessions);
$('archive-filter').addEventListener('change', () => { state.page = 1; refresh({ force: true }); });
for (const [id, delta] of [['session-prev', -1], ['session-next', 1]]) $(id).addEventListener('click', () => { state.page += delta; refresh({ force: true }); });
for (const id of ['asset-search', 'asset-filter']) $(id).addEventListener(id === 'asset-search' ? 'input' : 'change', () => { state.assetPage = 1; renderAssets(); });
for (const [id, delta] of [['asset-prev', -1], ['asset-next', 1]]) $(id).addEventListener('click', () => { state.assetPage += delta; renderAssets(); });
$('close-detail').addEventListener('click', () => $('detail-dialog').close());
$('detail-dialog').addEventListener('close', () => { state.selected = null; });
for (const [id, kind] of [['rename-session', 'rename'], ['archive-session', 'archive'], ['stop-session', 'stop']]) $(id).addEventListener('click', () => prepareAction(kind));
$('cancel-action').addEventListener('click', () => $('action-dialog').close());
$('action-dialog').addEventListener('cancel', event => { if (state.mutationBusy) event.preventDefault(); });
$('action-dialog').addEventListener('close', () => { state.action = null; });
$('action-input').addEventListener('input', () => $('action-input').setCustomValidity(''));
$('action-form').addEventListener('submit', submitAction);
for (const id of ['detail-dialog', 'action-dialog']) $(id).addEventListener('click', event => {
  if (event.target !== $(id) || state.mutationBusy) return;
  const rect = $(id).getBoundingClientRect();
  if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) $(id).close();
});
window.addEventListener('hashchange', navigate);
navigate();
request('/admin-config').then(config => {
  $('environment').textContent = config.environment;
  $('connection-label').title = config.agentBaseUrl;
}).catch(error => toast(error.message, true));
refresh();
setInterval(() => {
  if ($('auto-refresh').checked && !document.hidden && !state.mutationBusy && !$('action-dialog').open) refresh();
}, 5000);
