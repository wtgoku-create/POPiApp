import 'conversation_snapshot.dart';

/// 统一三个任务来源的阶段及固定版本产物，保留各自的操作协议。
class ConversationTaskView {
  ConversationTaskView(ConversationBlock block, ConversationSnapshot? snapshot)
    : steps = conversationMaps(block.data['steps'])
          .map(
            (step) => ConversationTaskStep.fromJson(step, snapshot: snapshot),
          )
          .toList(),
      proposals = conversationMaps(
        block.data['proposals'],
      ).map(ConversationTaskProposal.fromJson).toList(),
      errorCode = block.data['errorCode'] as String?,
      error = block.data['error'] as String?,
      title = block.title.isNotEmpty
          ? block.title
          : block.request?['brief'] as String? ?? '' {
    final input = block.data['input'];
    final cast = input is Map && input['cast'] is List
        ? input['cast']
        : snapshot?.source['sessionCast'];
    roles = [for (final role in conversationMaps(cast)) _role(role, snapshot)];
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
  late final List<ConversationBlock> roles;

  static ConversationBlock _role(
    Map<String, Object?> role,
    ConversationSnapshot? snapshot,
  ) {
    final version = role['versionId'];
    final candidates = [
      ...conversationMaps(snapshot?.source['sessionCast']),
      for (final message in snapshot?.messages ?? <ConversationMessage>[])
        for (final block in message.blocks) ...[
          if (block.kind == 'role') block.data,
          for (final cast in block.homeCast) cast.data,
        ],
    ];
    final saved = version == null
        ? null
        : candidates.where((candidate) {
            final profileVersion = candidate['profileVersion'];
            return candidate['id']?.toString() == role['roleId']?.toString() &&
                (candidate['versionId'] == version ||
                    profileVersion is Map && profileVersion['id'] == version);
          }).firstOrNull;
    final profile = role['profile'] is Map
        ? conversationMap(role['profile'])
        : role['profileVersion'] is Map
        ? conversationMap(conversationMap(role['profileVersion'])['profile'])
        : <String, Object?>{};
    return ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'role',
      'action': 'cast',
      'data': {
        ...?saved,
        ...role,
        'id': role['roleId'] ?? role['id'],
        if (version != null)
          'ref': {'kind': 'role', 'id': role['roleId'], 'versionId': version},
        'profile': profile,
        'title': profile['title'] ?? role['title'],
        'avatar': role['avatar'] ?? saved?['avatar'] ?? profile['avatar'],
        'threeViewImage':
            role['threeViewImage'] ??
            saved?['threeViewImage'] ??
            profile['threeViewImage'],
      },
    });
  }
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
  ConversationTaskStep.fromJson(
    Map<String, Object?> json, {
    ConversationSnapshot? snapshot,
  }) : key = json['key'] as String? ?? '',
       state = (json['state'] ?? json['status']) as String? ?? 'pending',
       content = _content(json, snapshot),
       mediaIds = {
         if (json['output'] is Map &&
             (json['output'] as Map)['mediaId'] != null)
           (json['output'] as Map)['mediaId'].toString(),
         if (json['output'] is List)
           for (final ref in conversationMaps(json['output']))
             if (ref['kind'] == 'media') ref['id'].toString(),
       }.toList();
  final String key;
  final String state;
  final ConversationBlock? content;
  final List<String> mediaIds;
  static ConversationBlock? _content(
    Map<String, Object?> json,
    ConversationSnapshot? snapshot,
  ) {
    final output = json['output'];
    final result = json['result'];
    var raw = output is Map
        ? conversationMap(output)
        : result is Map && result['content'] is Map
        ? conversationMap(result['content'])
        : null;
    if (raw == null) return null;
    // Reference-only updates resolve the saved version, never the latest one.
    if (raw['body'] == null &&
        raw['payload'] == null &&
        raw['versionId'] != null) {
      final reference = raw;
      final saved =
          [
                for (final item in conversationMaps(
                  snapshot?.source['contents'],
                ))
                  ConversationBlock.fromJson({
                    'type': 'object',
                    'kind': 'content',
                    'data': item,
                  }),
                for (final message
                    in snapshot?.messages ?? <ConversationMessage>[])
                  ...message.blocks.where((block) => block.kind == 'content'),
              ]
              .where(
                (block) =>
                    block.referenceId == reference['id']?.toString() &&
                    block.reference?['versionId'] == reference['versionId'],
              )
              .firstOrNull;
      if (saved != null) raw = {...saved.data, ...raw};
    }
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
