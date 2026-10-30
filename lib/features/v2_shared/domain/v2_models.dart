import 'package:flutter/foundation.dart';

import 'v2_question.dart';
export 'v2_question.dart';

enum V2SessionKind { conversation, project, workflow }

enum V2AssetKind { image, video, script, audio }

@immutable
class V2Message {
  const V2Message({
    required this.id,
    required this.text,
    this.user = false,
    this.assetIds = const [],
    this.status = '',
    this.question,
  });
  final String id;
  final String text;
  final bool user;
  final List<String> assetIds;
  final String status;
  final V2Question? question;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'user': user,
    'assets': assetIds,
    'status': status,
    if (question != null) 'question': question!.toJson(),
  };
  factory V2Message.fromJson(Map<String, Object?> json) => V2Message(
    id: json['id'] as String,
    text: json['text'] as String,
    user: json['user'] as bool,
    assetIds: (json['assets'] as List).cast<String>(),
    status: json['status'] as String? ?? '',
    question: json['question'] is Map
        ? V2Question.fromJson(
            Map<String, Object?>.from(json['question'] as Map),
          )
        : null,
  );
}

@immutable
class V2Session {
  const V2Session({
    required this.id,
    required this.title,
    required this.kind,
    required this.members,
    required this.roles,
    required this.messages,
    this.unread = 0,
    this.time = '',
    this.direction = '',
    this.positioning = '',
    this.capabilities = const ['character', 'script', 'image'],
    this.memberNames = const {},
    this.memberInstructions = const {},
    this.memberAvatars = const {},
    this.memberColors = const {},
    this.accountPreferences = const {},
    this.configuration = const {},
    this.configRevision = 0,
    this.serverRevision = 0,
    this.lastSeq = 0,
    this.running = false,
    this.canStop = true,
  });
  final String id;
  final String title;
  final V2SessionKind kind;
  final List<String> members;
  final List<String> roles;
  final List<V2Message> messages;
  final int unread;
  final String time;
  final String direction;
  final String positioning;
  final List<String> capabilities;
  final Map<String, String> memberNames;
  final Map<String, String> memberInstructions;
  final Map<String, String> memberAvatars;
  final Map<String, int> memberColors;
  final Map<String, String> accountPreferences;
  // Preserve server fields that this UI does not edit in replacement PATCHes.
  final Map<String, Object?> configuration;
  final int configRevision;
  final int serverRevision;
  final int lastSeq;
  final bool running;
  final bool canStop;

  V2Session copyWith({
    String? title,
    List<String>? members,
    List<String>? roles,
    List<V2Message>? messages,
    int? unread,
    String? time,
    String? direction,
    String? positioning,
    List<String>? capabilities,
    Map<String, String>? memberNames,
    Map<String, String>? memberInstructions,
    Map<String, String>? memberAvatars,
    Map<String, int>? memberColors,
    Map<String, String>? accountPreferences,
    Map<String, Object?>? configuration,
    int? configRevision,
    int? serverRevision,
    int? lastSeq,
    bool? running,
    bool? canStop,
  }) => V2Session(
    id: id,
    title: title ?? this.title,
    kind: kind,
    members: members ?? this.members,
    roles: roles ?? this.roles,
    messages: messages ?? this.messages,
    unread: unread ?? this.unread,
    time: time ?? this.time,
    direction: direction ?? this.direction,
    positioning: positioning ?? this.positioning,
    capabilities: capabilities ?? this.capabilities,
    memberNames: memberNames ?? this.memberNames,
    memberInstructions: memberInstructions ?? this.memberInstructions,
    memberAvatars: memberAvatars ?? this.memberAvatars,
    memberColors: memberColors ?? this.memberColors,
    accountPreferences: accountPreferences ?? this.accountPreferences,
    configuration: configuration ?? this.configuration,
    configRevision: configRevision ?? this.configRevision,
    serverRevision: serverRevision ?? this.serverRevision,
    lastSeq: lastSeq ?? this.lastSeq,
    running: running ?? this.running,
    canStop: canStop ?? this.canStop,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'members': members,
    'roles': roles,
    'messages': messages.map((m) => m.toJson()).toList(),
    'unread': unread,
    'time': time,
    'direction': direction,
    'positioning': positioning,
    'capabilities': capabilities,
    'memberNames': memberNames,
    'memberInstructions': memberInstructions,
    'memberAvatars': memberAvatars,
    'memberColors': memberColors,
    'accountPreferences': accountPreferences,
  };
  factory V2Session.fromJson(Map<String, Object?> json) => V2Session(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: V2SessionKind.values.byName(json['kind'] as String),
    members: (json['members'] as List).cast<String>(),
    roles: (json['roles'] as List).cast<String>(),
    messages: (json['messages'] as List)
        .map((m) => V2Message.fromJson(Map<String, Object?>.from(m as Map)))
        .toList(),
    unread: json['unread'] as int,
    time: json['time'] as String,
    direction: json['direction'] as String,
    positioning: json['positioning'] as String,
    capabilities: (json['capabilities'] as List).cast<String>(),
    memberNames: Map<String, String>.from(json['memberNames'] as Map? ?? {}),
    memberInstructions: Map<String, String>.from(
      json['memberInstructions'] as Map? ?? {},
    ),
    memberAvatars: Map<String, String>.from(
      json['memberAvatars'] as Map? ?? {},
    ),
    memberColors: Map<String, int>.from(json['memberColors'] as Map? ?? {}),
    accountPreferences: Map<String, String>.from(
      json['accountPreferences'] as Map? ?? {},
    ),
  );
}

@immutable
class V2Asset {
  const V2Asset({
    required this.id,
    required this.title,
    required this.kind,
    required this.cover,
    this.sessionId,
    this.body = '',
    this.media = '',
    this.contentUrl = '',
    this.businessAssetId = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.durationSeconds = 0,
    this.headers = const {},
  });
  final String id;
  final String title;
  final V2AssetKind kind;
  final String cover;
  final String? sessionId;
  final String body;
  final String media;
  final String contentUrl;
  final String businessAssetId;
  final String mimeType;
  final int sizeBytes;
  final double durationSeconds;
  final Map<String, String> headers;
  bool get isRemote => contentUrl.isNotEmpty;
  V2Asset copyWith({String? title}) => V2Asset(
    id: id,
    title: title ?? this.title,
    kind: kind,
    cover: cover,
    sessionId: sessionId,
    body: body,
    media: media,
    contentUrl: contentUrl,
    businessAssetId: businessAssetId,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    durationSeconds: durationSeconds,
    headers: headers,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'cover': cover,
    'sessionId': sessionId,
    'body': body,
    'media': media,
  };
  factory V2Asset.fromJson(Map<String, Object?> json) => V2Asset(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: V2AssetKind.values.byName(json['kind'] as String),
    cover: json['cover'] as String,
    sessionId: json['sessionId'] as String?,
    body: json['body'] as String,
    media: json['media'] as String,
  );
}

@immutable
class V2Character {
  const V2Character(
    this.id,
    this.name,
    this.image, {
    this.instructions = '',
    this.category = '',
    this.headers = const {},
  });
  final String id;
  final String name;
  final String image;
  final String instructions;
  final String category;
  final Map<String, String> headers;
}
