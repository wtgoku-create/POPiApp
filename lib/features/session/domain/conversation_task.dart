import 'conversation_snapshot.dart';

/// 统一三个任务来源的阶段及固定版本产物，保留各自的操作协议。
class ConversationTaskView {
  ConversationTaskView(ConversationBlock block, ConversationSnapshot? snapshot)
    : steps = conversationMaps(
        block.data['steps'],
      ).map(ConversationTaskStep.fromJson).toList(),
      proposals = conversationMaps(
        block.data['proposals'],
      ).map(ConversationTaskProposal.fromJson).toList(),
      errorCode = block.data['errorCode'] as String?,
      error = block.data['error'] as String?,
      title = block.title.isNotEmpty
          ? block.title
          : block.request?['brief'] as String? ?? '' {
    final stepMediaIds = {
      for (final step in steps) ...step.mediaIds,
      for (final step in steps) ...?step.content?.mediaIds,
    };
    mediaIds = {
      ...block.mediaIds,
      for (final receipt in conversationMaps(
        block.data['proposals'],
      ).expand((proposal) => conversationMaps(proposal['businessTasks'])))
        for (final ref in conversationMaps(receipt['outputs']))
          if (ref['kind'] == 'media') ref['id'].toString(),
      for (final message in snapshot?.messages ?? <ConversationMessage>[])
        for (final content in message.blocks)
          if (content.kind == 'content' &&
              conversationMaps(
                block.data['outputs'],
              ).any((ref) => ref['id'].toString() == content.referenceId))
            ...content.mediaIds,
    }.where((id) => !stepMediaIds.contains(id)).toList();
  }
  final List<ConversationTaskStep> steps;
  final List<ConversationTaskProposal> proposals;
  final String? errorCode;
  final String? error;
  final String title;
  late final List<String> mediaIds;
}

class ConversationTaskProposal {
  ConversationTaskProposal.fromJson(this.data)
    : status = data['status'] as String? ?? '',
      executionAvailable = data['executionAvailable'] != false,
      prompts = conversationMaps(
        data['plan'] is Map ? conversationMap(data['plan'])['items'] : null,
      ).map((item) => item['prompt'] as String? ?? '').toList(),
      estimatedPoints =
          (data['estimate'] is Map
              ? conversationMap(data['estimate'])['estimatedPoints'] as num?
              : null) ??
          (data['quote'] is Map
              ? conversationMap(data['quote'])['maxPoints'] as num?
              : null);
  final Map<String, Object?> data;
  final String status;
  final bool executionAvailable;
  final List<String> prompts;
  final num? estimatedPoints;
}

class ConversationTaskStep {
  ConversationTaskStep.fromJson(Map<String, Object?> json)
    : key = json['key'] as String? ?? '',
      state = (json['state'] ?? json['status']) as String? ?? 'pending',
      content = _content(json),
      mediaIds = {
        if (json['output'] is Map && (json['output'] as Map)['mediaId'] != null)
          (json['output'] as Map)['mediaId'].toString(),
        if (json['output'] is List)
          for (final ref in conversationMaps(json['output']))
            if (ref['kind'] == 'media') ref['id'].toString(),
      }.toList();
  final String key;
  final String state;
  final ConversationBlock? content;
  final List<String> mediaIds;
  static ConversationBlock? _content(Map<String, Object?> json) {
    final output = json['output'];
    final result = json['result'];
    final raw = output is Map
        ? conversationMap(output)
        : result is Map && result['content'] is Map
        ? conversationMap(result['content'])
        : null;
    if (raw == null) return null;
    final payload = raw['payload'];
    return ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'content',
      'data': {
        ...raw,
        if (payload is Map)
          'body':
              payload['text'] ??
              payload['body'] ??
              payload['description'] ??
              '',
        'editable': false,
      },
    });
  }
}
