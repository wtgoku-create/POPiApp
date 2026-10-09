import 'dart:convert';

import '../../../core/network/agent_api_exception.dart';
import '../domain/conversation_snapshot.dart';

class ConversationEvent {
  ConversationEvent.fromJson(Map<String, Object?> json)
    : sessionId = json['sessionId'] as String,
      seq = json['seq'] as int,
      type = json['type'] as String,
      payload = conversationMap(json['payload']),
      source = json;
  final String sessionId;
  final int seq;
  final String type;
  final Map<String, Object?> payload;
  final Map<String, Object?> source;
}

/// UTF-8 and LineSplitter retain incomplete characters and CRLF across chunks.
Stream<ConversationEvent> decodeConversationEvents(
  Stream<List<int>> bytes,
) async* {
  var data = <String>[];
  var firstLine = true;
  await for (var line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (firstLine) {
      line = line.replaceFirst(RegExp('^\uFEFF'), '');
      firstLine = false;
    }
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield ConversationEvent.fromJson(
          conversationMap(jsonDecode(data.join('\n'))),
        );
        data = [];
      }
      continue;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'data') data.add(value);
  }
  // An incomplete final frame is replayed from lastSeq on reconnection.
}

Never _snapshotRequired(String message) => throw AgentApiException(
  code: 'SNAPSHOT_REQUIRED',
  statusCode: 409,
  message: message,
);

ConversationSnapshot applyConversationEvent(
  ConversationSnapshot snapshot,
  ConversationEvent event,
) {
  // 重连会重放事件；重复事件不追加文本，缺号则重新拉快照，避免漏消息。
  if (event.sessionId != snapshot.session.id || event.seq <= snapshot.lastSeq) {
    return snapshot;
  }
  if (event.seq != snapshot.lastSeq + 1) {
    _snapshotRequired('Event sequence gap');
  }
  final next = {...snapshot.source, 'lastSeq': event.seq};
  final p = event.payload;
  if (next['timelineVersion'] == 1) {
    final messages = {
      for (final message in snapshot.messages) message.id: message,
    };
    for (final item in conversationMaps(p['timelineUpdates'])) {
      if (item['sessionId'] != snapshot.session.id ||
          item['seq'] is! int ||
          item['revision'] is! int) {
        _snapshotRequired('Invalid timeline update');
      }
      final message = ConversationMessage.fromJson(item);
      final previous = messages[message.id];
      if (previous == null || previous.revision < message.revision) {
        // 对象更新只替换内容，保留最初的位置与时间，防止历史消息跳动。
        messages[message.id] = previous == null
            ? message
            : message.anchoredTo(previous);
      }
    }
    if (event.type == 'message.delta' &&
        p['messageId'] is String &&
        p['delta'] is String) {
      final previous = messages[p['messageId']];
      if (previous == null) _snapshotRequired('Message anchor missing');
      if (previous.revision < event.seq) {
        final blocks = [...previous.blocks];
        if (blocks.isNotEmpty && blocks.last.type == 'text') {
          blocks[blocks.length - 1] = ConversationBlock.text(
            blocks.last.text + (p['delta'] as String),
          );
        } else {
          blocks.add(ConversationBlock.text(p['delta'] as String));
        }
        messages[previous.id] = previous.withBlocks(blocks, event.seq);
      }
    }
    next['timelineMessages'] = [
      for (final message in messages.values) _messageJson(message),
    ];
  } else {
    var messages = conversationMaps(next['messages']);
    if ([
          'message.started',
          'message.updated',
          'message.completed',
          'context.recorded',
        ].contains(event.type) &&
        p['messageId'] is String) {
      final previous = messages
          .where((item) => item['id'] == p['messageId'])
          .firstOrNull;
      messages = [
        ...messages.where(
          (item) =>
              item['id'] != p['messageId'] &&
              item['id'] != 'stream:${p['runId']}',
        ),
        {
          ...?previous,
          ...p,
          'id': p['messageId'],
          'taskId': event.source['taskId'],
          'seq': previous?['seq'] ?? event.seq,
          'createdAt': previous?['createdAt'] ?? event.source['occurredAt'],
          'transient': event.type == 'message.started',
        },
      ];
    }
    if (event.type == 'message.delta' &&
        p['runId'] is String &&
        p['delta'] is String) {
      final id = p['messageId'] ?? 'stream:${p['runId']}';
      final previous = messages.where((item) => item['id'] == id).firstOrNull;
      messages = [
        ...messages.where((item) => item['id'] != id),
        {
          ...?previous,
          'id': id,
          'runId': p['runId'],
          'role': 'assistant',
          'text': '${previous?['text'] ?? ''}${p['delta']}',
          'transient': true,
          'seq': previous?['seq'] ?? event.seq,
          'createdAt': previous?['createdAt'] ?? event.source['occurredAt'],
        },
      ];
    }
    next['messages'] = messages;
  }
  const runStates = {
    'run.started': 'running',
    'run.queued': 'pending',
    'run.pending': 'pending',
    'run.deferred': 'pending',
    'run.completed': 'completed',
    'run.failed': 'failed',
    'run.interrupted': 'interrupted',
    'run.canceled': 'canceled',
    'run.aborted': 'aborted',
  };
  if (runStates.containsKey(event.type) && p['runId'] is String) {
    final runs = conversationMaps(next['runs']);
    final previous = runs.where((item) => item['id'] == p['runId']).firstOrNull;
    next['runs'] = [
      ...runs.where((item) => item['id'] != p['runId']),
      {
        ...?previous,
        ...p,
        'id': p['runId'],
        'state': runStates[event.type],
        'purpose':
            p['purpose'] ??
            previous?['purpose'] ??
            (event.source['taskId'] == null ? 'conversation' : 'stage'),
        'errorCode': p['code'],
      },
    ];
    if (!['pending', 'running'].contains(runStates[event.type])) {
      // 停止或失败也保留已经输出的文字，服务端快照负责后续恢复。
      next['messages'] = [
        for (final item in conversationMaps(next['messages']))
          {...item, if (item['runId'] == p['runId']) 'transient': false},
      ];
    }
  }
  if (event.type == 'session.updated' || event.type == 'session.bound') {
    next['session'] = {
      ...conversationMap(next['session']),
      if (event.type == 'session.bound') 'bindingStatus': 'ready',
      if (event.type == 'session.updated') ...{
        ...p,
        'revision': event.source['stateVersion'],
        'updatedAt': event.source['occurredAt'],
        if (p['pinned'] is bool)
          'pinnedAt': p['pinned'] == true ? event.source['occurredAt'] : null,
      },
    };
  }
  for (final (prefix, field, payloadField) in [
    ('content.', 'contents', 'content'),
    ('confirmation.', 'confirmations', 'confirmation'),
    ('home.task.', 'homeTasks', 'task'),
  ]) {
    if (!event.type.startsWith(prefix) || p[payloadField] == null) continue;
    final item = conversationMap(p[payloadField]);
    final items = conversationMaps(next[field]);
    final previous = items.where((old) => old['id'] == item['id']).firstOrNull;
    if (previous == null ||
        (previous['revision'] as int? ?? 0) <=
            (item['revision'] as int? ?? event.seq)) {
      next[field] = [
        ...items.where((old) => old['id'] != item['id']),
        {
          ...item,
          'seq': previous?['seq'] ?? item['seq'] ?? event.seq,
          'createdAt':
              previous?['createdAt'] ??
              item['createdAt'] ??
              event.source['occurredAt'],
        },
      ];
    }
  }
  return ConversationSnapshot.fromJson(next);
}

Map<String, Object?> _messageJson(ConversationMessage message) => {
  'id': message.id,
  'sessionId': message.sessionId,
  'role': message.role,
  'seq': message.seq,
  'revision': message.revision,
  'runId': message.runId,
  'createdAt': message.createdAt.toIso8601String(),
  'blocks': [
    for (final block in message.blocks)
      {
        'type': block.type,
        if (block.type == 'text') 'text': block.text,
        if (block.mediaId != null) 'mediaId': block.mediaId,
        if (block.kind != null) ...{
          'kind': block.kind,
          'action': block.action,
          'data': block.data,
        },
      },
  ],
};
