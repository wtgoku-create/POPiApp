import 'conversation_session.dart';

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
      data = json['data'] == null ? const {} : conversationMap(json['data']);

  ConversationBlock.text(this.text)
    : type = 'text',
      mediaId = null,
      kind = null,
      action = null,
      data = const {};

  final String type;
  final String text;
  final String? mediaId;
  final String? kind;
  final String? action;
  final Map<String, Object?> data;

  String get id => data['id']?.toString() ?? '';
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
  List<String> get mediaIds => [
    if (mediaId != null) mediaId!,
    ...((data['mediaIds'] as List?) ?? []).whereType<String>(),
    for (final output in conversationMaps(data['outputs']))
      if (output['kind'] == 'media') output['id'].toString(),
  ];
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
      retryable = json['retryable'] == true,
      error = json['message'] as String?,
      errorCode = json['errorCode'] as String?;
  final String id;
  final String state;
  final String purpose;
  final bool retryable;
  final String? error;
  final String? errorCode;
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
