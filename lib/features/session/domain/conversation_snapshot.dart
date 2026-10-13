import 'dart:convert';

import 'conversation_session.dart';
import '../../role_guide/domain/home_storyboard.dart';

Map<String, Object?> conversationMap(Object? value) {
  if (value is! Map) throw const FormatException('Invalid conversation object');
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> conversationMaps(Object? value) =>
    value == null ? [] : (value as List).map(conversationMap).toList();

/// Preserves structured timeline objects alongside text and media blocks.
class ConversationBlock {
  ConversationBlock.fromJson(Map<String, Object?> json)
    : type = json['type'] as String,
      text = json['text'] as String? ?? '',
      mediaId = json['mediaId'] as String?,
      kind = json['kind'] as String?,
      action = json['action'] as String?,
      scope = json['scope'] == null ? const {} : conversationMap(json['scope']),
      data = json['data'] == null ? const {} : conversationMap(json['data']);

  ConversationBlock.text(this.text)
    : type = 'text',
      mediaId = null,
      kind = null,
      action = null,
      scope = const {},
      data = const {};

  final String type;
  final String text;
  final String? mediaId;
  final String? kind;
  final String? action;
  final Map<String, Object?> scope;
  final Map<String, Object?> data;

  String get id => data['id']?.toString() ?? '';
  String get referenceId {
    final ref = data['ref'];
    return ref is Map ? conversationMap(ref)['id']?.toString() ?? id : id;
  }

  String? get scopeId => scope['id']?.toString();
  String? get scopeKind => scope['kind'] as String?;
  int get revision => data['revision'] as int? ?? 1;
  String get title => data['title'] as String? ?? '';
  String get status => (data['status'] ?? data['state']) as String? ?? '';
  String get body =>
      (data['body'] ??
              data['summary'] ??
              data['description'] ??
              data['configuration'])
          as String? ??
      '';
  String get objectKind => data['kind'] as String? ?? '';
  bool get isHomePlan => kind == 'plan' && data['homePlan'] is Map;
  Map<String, Object?>? get reference =>
      data['ref'] is Map ? conversationMap(data['ref']) : null;
  Map<String, Object?>? get roleImage =>
      data['roleImage'] is Map ? conversationMap(data['roleImage']) : null;
  bool get isThreeView => planItems.firstOrNull?['key'] == 'three_view';
  String get mediaType =>
      (planItems.firstOrNull?['mediaType'] ?? data['mediaType']) as String? ??
      '';
  String get configuration => data['configuration'] as String? ?? '';
  String get hook => data['hook'] as String? ?? '';
  List<ConversationBlock> get homeCast => [
    for (final role in conversationMaps(
      data['homePlan'] is Map
          ? conversationMap(data['homePlan'])['cast']
          : null,
    ))
      ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'role',
        'action': 'cast',
        'data': role,
      }),
  ];
  ConversationBlock? get homeTopic {
    final plan = data['homePlan'];
    if (plan is! Map || plan['topic'] is! Map) return null;
    return ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'topic',
      'action': 'selected',
      'data': plan['topic'],
    });
  }

  ConversationBlock? get previewRole {
    final role = data['roleDraft'] ?? roleImage?['role'];
    if (role is Map) {
      return ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'role',
        'action': 'edited',
        'data': role,
      });
    }
    final input = data['roleInput'];
    if (input is! Map) return null;
    final profile = input['profile'];
    if (profile is! Map) return null;
    return ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'role',
      'action': 'created',
      'data': {
        'title': profile['title'],
        'profile': profile,
        'description': profile['description'],
        'avatar': input['avatar'],
        'threeViewImage': input['threeViewImage'],
        'status': 'draft',
      },
    });
  }

  List<(String, String, String)> get profileChanges {
    final before = data['before'] is Map
        ? conversationMap(data['before'])
        : <String, Object?>{};
    final fields = before['profileData'] is Map
        ? conversationMap(before['profileData'])
        : <String, Object?>{};
    final changes = data['changes'] is Map
        ? conversationMap(data['changes'])
        : <String, Object?>{};
    return [
      for (final entry in changes.entries)
        (
          entry.key,
          _displayValue(
            before[entry.key] ??
                (fields[entry.key] is Map
                    ? (fields[entry.key] as Map)['value']
                    : null),
          ),
          _displayValue(entry.value),
        ),
    ];
  }

  bool get editableContent =>
      kind == 'content' &&
      objectKind != 'profile' &&
      data['editable'] == true &&
      reference?['versionId'] != null;
  HomeStoryboard? get storyboard =>
      objectKind == 'storyboard' ? HomeStoryboard.tryParse(body) : null;
  List<String> get mediaIds => {
    if (mediaId != null) mediaId!,
    if (data['mediaId'] != null) data['mediaId'].toString(),
    for (final id in (data['mediaIds'] as List?) ?? [])
      if (id != null) id.toString(),
    for (final output in conversationMaps(data['outputs']))
      if (output['kind'] == 'media' && output['id'] != null)
        output['id'].toString(),
  }.where((id) => id.isNotEmpty).toList();
  List<ConversationQuestionField> get fields => conversationMaps(
    data['fields'],
  ).map(ConversationQuestionField.fromJson).toList();
  Map<String, Object?> get answer =>
      data['answer'] == null ? const {} : conversationMap(data['answer']);
  List<String> get allowedActions =>
      ((data['allowedActions'] as List?) ?? []).whereType<String>().toList();
  bool get confirmationAvailable {
    final expiry = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
    return ['ready', 'submitting', 'failed'].contains(status) &&
        (expiry == null || expiry.isAfter(DateTime.now()));
  }

  num? get estimatedPoints => data['estimatedPoints'] as num?;
  String? get expiresAt => data['expiresAt'] as String?;
  List<String> get planPrompts =>
      planItems.map((item) => item['prompt'] as String? ?? '').toList();
  List<(String, String)> get answeredFields => [
    for (final field in fields)
      if (answer[field.id] != null)
        (
          field.label,
          answer[field.id] is List
              ? (answer[field.id] as List).join(', ')
              : answer[field.id].toString(),
        ),
  ];
  List<ConversationBlock> get results => [
    for (final step in conversationMaps(data['steps']))
      if (step['output'] is Map)
        ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'content',
          'data': {
            ...conversationMap(step['output']),
            if (conversationMap(step['output'])['mediaId'] != null)
              'mediaIds': [conversationMap(step['output'])['mediaId']],
          },
        }),
  ];
  List<Map<String, Object?>> get planItems => data['plan'] == null
      ? const []
      : conversationMaps(conversationMap(data['plan'])['items']);
  List<(String, String)> get progressSteps => [
    for (final step in conversationMaps(data['steps']))
      if (step['labelKey'] is String)
        (step['labelKey'] as String, step['status'] as String? ?? 'pending'),
  ];
  Map<String, Object?>? get request =>
      data['request'] == null ? null : conversationMap(data['request']);
  String? get avatar => (data['avatar'] ?? data['threeViewImage']) as String?;
  List<(String, String)> get details {
    final profile = data['profile'];
    if (profile is! Map) return const [];
    return [
      for (final entry in profile.entries)
        if (entry.value is String && (entry.value as String).isNotEmpty)
          (entry.key.toString(), entry.value as String)
        else if (entry.value is List && (entry.value as List).isNotEmpty)
          (entry.key.toString(), (entry.value as List).join(', ')),
      if (profile['profileData'] is Map)
        for (final field in conversationMap(profile['profileData']).values)
          if (field is Map &&
              field['label'] is String &&
              field['value'] != null)
            (
              field['label'] as String,
              field['value'] is List
                  ? (field['value'] as List).join(', ')
                  : field['value'].toString(),
            ),
    ];
  }
}

class ConversationQuestionField {
  ConversationQuestionField.fromJson(Map<String, Object?> json)
    : id = json['id'] as String,
      label = json['label'] as String,
      multiple = json['type'] == 'multi_select',
      required = json['required'] == true,
      options = ((json['options'] as List?) ?? []).whereType<String>().toList();
  final String id;
  final String label;
  final bool multiple;
  final bool required;
  final List<String> options;
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.role,
    required this.seq,
    required this.revision,
    required this.createdAt,
    required this.blocks,
    this.runId,
    this.sessionId,
    this.transient = false,
    this.attempt,
    this.presentation,
  });

  factory ConversationMessage.fromJson(
    Map<String, Object?> json, {
    bool timeline = true,
  }) => ConversationMessage(
    id: json['id'] as String,
    sessionId: json['sessionId'] as String?,
    role: json['role'] as String? ?? 'assistant',
    seq: json['seq'] as int? ?? 0,
    revision: json['revision'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    runId: json['runId'] as String?,
    transient: json['transient'] == true,
    attempt: json['attempt'] as int?,
    presentation: json['presentation'] as String?,
    blocks: timeline
        ? conversationMaps(
            json['blocks'],
          ).map(ConversationBlock.fromJson).toList()
        : [
            ConversationBlock.text(json['text'] as String? ?? ''),
            for (final id in (json['mediaIds'] as List?) ?? [])
              ConversationBlock.fromJson({'type': 'media', 'mediaId': id}),
          ],
  );

  final String id;
  final String? sessionId;
  final String role;
  final int seq;
  final int revision;
  final DateTime createdAt;
  final String? runId;
  final bool transient;
  final int? attempt;
  final String? presentation;
  final List<ConversationBlock> blocks;

  String get text => blocks
      .where((block) => block.type == 'text')
      .map((block) => block.text)
      .join('\n\n');
  ConversationMessage withBlocks(List<ConversationBlock> value, int version) =>
      ConversationMessage(
        id: id,
        sessionId: sessionId,
        role: role,
        seq: seq,
        revision: version,
        createdAt: createdAt,
        runId: runId,
        transient: transient,
        attempt: attempt,
        presentation: presentation,
        blocks: value,
      );
  ConversationMessage anchoredTo(ConversationMessage previous) =>
      ConversationMessage(
        id: id,
        sessionId: sessionId,
        role: role,
        seq: previous.seq,
        revision: revision,
        createdAt: previous.createdAt,
        runId: runId,
        transient: transient,
        attempt: attempt,
        presentation: presentation,
        blocks: blocks,
      );
}

class ConversationRun {
  ConversationRun.fromJson(Map<String, Object?> json)
    : id = json['id'] as String,
      state = json['state'] as String,
      purpose =
          json['purpose'] as String? ??
          (json['taskId'] == null ? 'conversation' : 'stage'),
      retryable =
          json['retryable'] as bool? ??
          ['failed', 'interrupted'].contains(json['state']),
      error = json['message'] as String?,
      errorCode = (json['errorCode'] ?? json['code']) as String?,
      attempt = json['attempt'] as int?;
  final String id;
  final String state;
  final String purpose;
  final bool retryable;
  final String? error;
  final String? errorCode;
  final int? attempt;
  bool get running =>
      ['conversation', 'consultation'].contains(purpose) &&
      ['pending', 'running'].contains(state);
}

/// The server remains the source of truth for ordering and object revisions.
class ConversationSnapshot {
  ConversationSnapshot.fromJson(Map<String, Object?> json)
    : source = Map.unmodifiable(json) {
    session = ConversationSession.fromJson(conversationMap(json['session']));
    lastSeq = json['lastSeq'] as int;
    if (lastSeq < 0) throw const FormatException('Invalid event cursor');
    final timeline = json['timelineVersion'] == 1;
    messages =
        conversationMaps(json[timeline ? 'timelineMessages' : 'messages'])
            .map(
              (item) => ConversationMessage.fromJson(item, timeline: timeline),
            )
            .toList();
    if (timeline &&
        messages.any((message) => message.sessionId != session.id)) {
      throw const FormatException('Invalid timeline session');
    }
    if (messages.map((message) => message.id).toSet().length !=
        messages.length) {
      throw const FormatException('Duplicate timeline message');
    }
    messages.sort((a, b) => a.seq.compareTo(b.seq));
    runs = conversationMaps(
      json['runs'],
    ).map(ConversationRun.fromJson).toList();
  }
  final Map<String, Object?> source;
  late final ConversationSession session;
  late final int lastSeq;
  late final List<ConversationMessage> messages;
  late final List<ConversationRun> runs;
  bool get running => runs.any((run) => run.running);

  /// 历史批次只读；后续选题或确认属于同一作品时锁定原候选。
  bool topicLocked(ConversationMessage message, ConversationBlock topic) =>
      topic.action == 'selected' ||
      topic.scopeKind != 'creation' ||
      topic.scopeId == null ||
      messages
          .where((item) => item.seq > message.seq)
          .any(
            (item) => item.blocks.any(
              (block) =>
                  block.kind == 'topic' &&
                  block.scopeId == topic.scopeId &&
                  ['selected', 'generated'].contains(block.action),
            ),
          );
  String? selectedTopicId(
    ConversationMessage message,
    ConversationBlock topic,
  ) => messages
      .where((item) => item.seq > message.seq)
      .expand((item) => item.blocks)
      .where(
        (block) =>
            block.kind == 'topic' &&
            block.action == 'selected' &&
            block.scopeId == topic.scopeId,
      )
      .firstOrNull
      ?.referenceId;
  List<ConversationBlock> get legacyObjects => source['timelineVersion'] == 1
      ? const []
      : [
          for (final item in conversationMaps(source['contents']))
            ConversationBlock.fromJson({
              'type': 'object',
              'kind': 'content',
              'data': item,
            }),
          for (final item in conversationMaps(source['confirmations']))
            ConversationBlock.fromJson({
              'type': 'object',
              'kind': 'plan',
              'data': item,
            }),
        ];
}

String _displayValue(Object? value) => value is Map
    ? value.containsKey('value')
          ? _displayValue(value['value'])
          : jsonEncode(value)
    : value is List
    ? value.map(_displayValue).join(', ')
    : value?.toString() ?? '';
