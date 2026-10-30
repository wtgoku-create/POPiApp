import 'package:flutter/foundation.dart';

import 'demo_style_film_models.dart';

export 'demo_style_film_models.dart';

enum DemoSessionKind { conversation, project, workflow }

enum DemoAssetKind { image, video, script, audio }

@immutable
class DemoRoleProfile {
  const DemoRoleProfile({
    this.name = '',
    this.instructions = '',
    this.revision = '',
    this.referenceAssetIds = const [],
    this.referenceImageUrls = const [],
    this.binding,
  });

  final String name;
  final String instructions;
  final String revision;
  final List<String> referenceAssetIds;
  final List<String> referenceImageUrls;
  final Map<String, Object?>? binding;

  bool get isReady =>
      (instructions.trim().isNotEmpty ||
          referenceAssetIds.isNotEmpty ||
          referenceImageUrls.isNotEmpty) &&
      revision.trim().isNotEmpty;

  DemoRoleProfile copyWith({
    String? name,
    String? instructions,
    String? revision,
    List<String>? referenceAssetIds,
    List<String>? referenceImageUrls,
    Map<String, Object?>? binding,
  }) => DemoRoleProfile(
    name: name ?? this.name,
    instructions: instructions ?? this.instructions,
    revision: revision ?? this.revision,
    referenceAssetIds: referenceAssetIds ?? this.referenceAssetIds,
    referenceImageUrls: referenceImageUrls ?? this.referenceImageUrls,
    binding: binding ?? this.binding,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'instructions': instructions,
    'revision': revision,
    'referenceAssetIds': referenceAssetIds,
    'referenceImageUrls': referenceImageUrls,
    if (binding != null) 'binding': binding,
  };

  factory DemoRoleProfile.fromJson(Map<String, Object?> json) =>
      DemoRoleProfile(
        name: json['name']?.toString() ?? '',
        instructions: json['instructions']?.toString() ?? '',
        revision: json['revision']?.toString() ?? '',
        binding: json['binding'] is Map
            ? Map<String, Object?>.from(json['binding'] as Map)
            : null,
        referenceAssetIds: List<String>.from(
          json['referenceAssetIds'] as List? ?? const [],
        ),
        referenceImageUrls: List<String>.from(
          json['referenceImageUrls'] as List? ?? const [],
        ),
      );
}

@immutable
class DemoMediaJob {
  const DemoMediaJob({
    required this.jobId,
    required this.state,
    required this.operation,
    required this.model,
    required this.runId,
    this.memberId = '',
    this.configRevision = 0,
    this.assetIds = const [],
    this.ingestionState = '',
    this.error = const {},
  });

  final String jobId;
  final String state;
  final String operation;
  final String model;
  final String runId;
  final String memberId;
  final int configRevision;
  final List<String> assetIds;
  final String ingestionState;
  final Map<String, Object?> error;

  bool get isPending {
    if (const {'failed', 'unknown', 'cancelled', 'stopped'}.contains(state)) {
      return false;
    }
    return const {
          'submitting',
          'pending',
          'queued',
          'running',
          'processing',
          'ingesting',
        }.contains(state) ||
        ingestionState == 'pending' ||
        ingestionState == 'ingesting';
  }

  Map<String, Object?> toJson() => {
    'jobId': jobId,
    'state': state,
    'operation': operation,
    'model': model,
    'runId': runId,
    if (memberId.isNotEmpty) 'memberId': memberId,
    'configRevision': configRevision,
    if (assetIds.isNotEmpty) 'assetIds': assetIds,
    if (ingestionState.isNotEmpty) 'ingestionState': ingestionState,
    if (error.isNotEmpty) 'error': error,
  };

  factory DemoMediaJob.fromJson(Map<String, Object?> json) => DemoMediaJob(
    jobId: json['jobId']?.toString() ?? '',
    state: json['state']?.toString() ?? '',
    operation: json['operation']?.toString() ?? '',
    model: json['model']?.toString() ?? '',
    runId: json['runId']?.toString() ?? '',
    memberId: json['memberId']?.toString() ?? '',
    configRevision: (json['configRevision'] as num?)?.toInt() ?? 0,
    assetIds: (json['assetIds'] as List? ?? const []).cast<String>(),
    ingestionState: json['ingestionState']?.toString() ?? '',
    error: json['error'] is Map
        ? Map<String, Object?>.from(json['error'] as Map)
        : const {},
  );
}

@immutable
class DemoQuestionOption {
  const DemoQuestionOption({required this.label, this.description = ''});

  final String label;
  final String description;

  Map<String, Object?> toJson() => {
    'label': label,
    if (description.isNotEmpty) 'description': description,
  };

  factory DemoQuestionOption.fromJson(Object? value) {
    if (value is String) return DemoQuestionOption(label: value);
    final json = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    return DemoQuestionOption(
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

@immutable
class DemoQuestionField {
  const DemoQuestionField({
    required this.id,
    required this.question,
    this.header = '',
    this.options = const [],
    this.multiSelect = false,
  });

  final String id;
  final String question;
  final String header;
  final List<DemoQuestionOption> options;
  final bool multiSelect;

  Map<String, Object?> toJson() => {
    'id': id,
    'question': question,
    if (header.isNotEmpty) 'header': header,
    'options': options.map((option) => option.toJson()).toList(),
    if (multiSelect) 'multiSelect': true,
  };

  factory DemoQuestionField.fromJson(Map<String, Object?> json) =>
      DemoQuestionField(
        id: json['id']?.toString() ?? '',
        question: json['question']?.toString() ?? '',
        header: json['header']?.toString() ?? '',
        options: ((json['options'] as List?) ?? const [])
            .map(DemoQuestionOption.fromJson)
            .where((option) => option.label.isNotEmpty)
            .toList(),
        multiSelect: json['multiSelect'] == true,
      );
}

@immutable
class DemoQuestionAnswer {
  const DemoQuestionAnswer({
    required this.id,
    this.selected = const [],
    this.custom = '',
  });

  final String id;
  final List<String> selected;
  final String custom;

  Map<String, Object?> toJson() => {
    'id': id,
    'selected': selected,
    if (custom.isNotEmpty) 'custom': custom,
  };

  factory DemoQuestionAnswer.fromJson(Map<String, Object?> json) =>
      DemoQuestionAnswer(
        id: json['id']?.toString() ?? '',
        selected: ((json['selected'] as List?) ?? const [])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(),
        custom: json['custom']?.toString() ?? '',
      );
}

@immutable
class DemoQuestion {
  const DemoQuestion({
    required this.id,
    required this.revision,
    required this.status,
    required this.questions,
    this.title = '',
    this.answers = const [],
  });

  final String id;
  final int revision;
  final String status;
  final String title;
  final List<DemoQuestionField> questions;
  final List<DemoQuestionAnswer> answers;

  bool get isPending => status == 'pending';

  /// Converts the DSH selected/custom answer projection into card values.
  Map<String, Object?> get answer {
    final byId = {for (final item in answers) item.id: item};
    return {
      for (final field in questions)
        if (byId[field.id] case final item?)
          field.id: field.multiSelect
              ? <String>{
                  ...item.selected,
                  if (item.custom.trim().isNotEmpty) item.custom.trim(),
                }.toList()
              : item.custom.trim().isNotEmpty
              ? item.custom.trim()
              : item.selected.firstOrNull ?? '',
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'status': status,
    if (title.isNotEmpty) 'title': title,
    'questions': questions.map((question) => question.toJson()).toList(),
    if (answers.isNotEmpty)
      'answers': answers.map((answer) => answer.toJson()).toList(),
  };

  factory DemoQuestion.fromJson(Map<String, Object?> json) => DemoQuestion(
    id: json['id']?.toString() ?? '',
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    status: json['status']?.toString() ?? 'pending',
    title: json['title']?.toString() ?? '',
    questions: ((json['questions'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              DemoQuestionField.fromJson(Map<String, Object?>.from(value)),
        )
        .where((field) => field.id.isNotEmpty && field.question.isNotEmpty)
        .toList(),
    answers: ((json['answers'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              DemoQuestionAnswer.fromJson(Map<String, Object?>.from(value)),
        )
        .where((answer) => answer.id.isNotEmpty)
        .toList(),
  );
}

/// Public, user-facing progress for one assistant turn.
///
/// Harness deliberately exposes only this bounded summary. Provider reasoning,
/// tool inputs, and tool outputs never enter the Flutter message model.
@immutable
class DemoActivityStep {
  const DemoActivityStep({
    required this.id,
    required this.kind,
    required this.status,
  });

  final String id;
  final String kind;
  final String status;

  Map<String, Object?> toJson() => {'id': id, 'kind': kind, 'status': status};

  factory DemoActivityStep.fromJson(Map<String, Object?> json) =>
      DemoActivityStep(
        id: json['id']?.toString() ?? '',
        kind: DemoActivity.normalizeKind(json['kind']),
        status: DemoActivity.normalizeStatus(json['status']),
      );
}

@immutable
class DemoActivity {
  const DemoActivity({
    required this.kind,
    required this.status,
    this.steps = const [],
  });

  static const kinds = {
    'thinking',
    'model',
    'search',
    'fetch',
    'image',
    'video',
    'script',
    'audio',
    'vision',
    'reply',
    'tool',
  };
  static const statuses = {
    'running',
    'completed',
    'failed',
    'stopped',
    'waiting_user',
  };

  final String kind;
  final String status;
  final List<DemoActivityStep> steps;

  bool get isActive => status == 'running' || status == 'waiting_user';

  DemoActivity copyWith({
    String? kind,
    String? status,
    List<DemoActivityStep>? steps,
  }) => DemoActivity(
    kind: kind ?? this.kind,
    status: status ?? this.status,
    steps: steps ?? this.steps,
  );

  Map<String, Object?> toJson() => {
    'kind': kind,
    'status': status,
    if (steps.isNotEmpty) 'steps': steps.map((step) => step.toJson()).toList(),
  };

  factory DemoActivity.fromJson(Map<String, Object?> json) => DemoActivity(
    kind: normalizeKind(json['kind']),
    status: normalizeStatus(json['status']),
    steps: ((json['steps'] as List?) ?? const [])
        .whereType<Map>()
        .take(12)
        .map(
          (value) =>
              DemoActivityStep.fromJson(Map<String, Object?>.from(value)),
        )
        .where((step) => step.id.isNotEmpty)
        .toList(),
  );

  static String normalizeKind(Object? value) {
    final kind = value?.toString() ?? '';
    return kinds.contains(kind) ? kind : 'tool';
  }

  static String normalizeStatus(Object? value) {
    final status = value?.toString() ?? '';
    return statuses.contains(status) ? status : 'completed';
  }
}

@immutable
class DemoMessage {
  const DemoMessage({
    required this.id,
    required this.text,
    this.user = false,
    this.assetIds = const [],
    this.status,
    this.memberId = '',
    this.memberName = '',
    this.runId = '',
    this.configRevision = 0,
    this.createdAt,
    this.question,
    this.activity,
    this.filmJobId = '',
  });
  final String id;
  final String text;
  final bool user;
  final List<String> assetIds;
  final String? status;
  final String memberId;
  final String memberName;
  final String runId;
  final int configRevision;
  final DateTime? createdAt;
  final DemoQuestion? question;
  final DemoActivity? activity;
  final String filmJobId;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'user': user,
    'assets': assetIds,
    if (status != null) 'status': status,
    if (memberId.isNotEmpty) 'memberId': memberId,
    if (memberName.isNotEmpty) 'memberName': memberName,
    if (runId.isNotEmpty) 'runId': runId,
    if (configRevision != 0) 'configRevision': configRevision,
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (question != null) 'question': question!.toJson(),
    if (activity != null) 'activity': activity!.toJson(),
    if (filmJobId.isNotEmpty) 'filmJobId': filmJobId,
  };
  factory DemoMessage.fromJson(Map<String, Object?> json) => DemoMessage(
    id: json['id']?.toString() ?? '',
    text: json['text']?.toString() ?? '',
    user: json['user'] as bool? ?? false,
    assetIds: (json['assets'] as List? ?? const []).cast<String>(),
    status: json['status'] as String?,
    memberId: json['memberId']?.toString() ?? '',
    memberName: json['memberName']?.toString() ?? '',
    runId: json['runId']?.toString() ?? '',
    configRevision: (json['configRevision'] as num?)?.toInt() ?? 0,
    createdAt: _parseDateTime(json['createdAt']),
    question: json['question'] is Map
        ? DemoQuestion.fromJson(
            Map<String, Object?>.from(json['question'] as Map),
          )
        : null,
    activity: json['activity'] is Map
        ? DemoActivity.fromJson(
            Map<String, Object?>.from(json['activity'] as Map),
          )
        : null,
    filmJobId: json['filmJobId']?.toString() ?? '',
  );
}

@immutable
class DemoCreativeMemory {
  const DemoCreativeMemory({this.text = '', this.source = 'ai'})
    : assert(source == 'ai' || source == 'user');

  final String text;
  final String source;

  bool get isUserEdited => source == 'user';

  Map<String, Object?> toJson() => {'text': text, 'source': source};

  factory DemoCreativeMemory.fromJson(Object? value) {
    final json = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    return DemoCreativeMemory(
      text: json['text']?.toString() ?? '',
      source: json['source'] == 'user' ? 'user' : 'ai',
    );
  }
}

@immutable
class DemoSession {
  static const defaultCapabilities = [
    'character',
    'script',
    'image',
    'video',
    'audio',
    'vision',
  ];

  const DemoSession({
    required this.id,
    required this.title,
    required this.kind,
    required this.members,
    required this.roles,
    required this.messages,
    this.unread = 0,
    this.time = '',
    this.updatedAt,
    this.direction = '',
    this.positioning = '',
    this.capabilities = defaultCapabilities,
    this.accountPreferences = const {},
    this.creativeMemory = const DemoCreativeMemory(),
    this.memberNames = const {},
    this.memberInstructions = const {},
    this.memberAvatars = const {},
    this.memberColors = const {},
    this.memberCapabilities = const {},
    this.memberSkills = const {},
    this.memberBotIds = const {},
    this.workMode = 'onDemand',
    this.activeMemberId = 'popi',
    this.roleProfiles = const {},
    this.configRevision = 0,
    this.configurationStatus = 'legacy',
    this.serverRevision = 0,
    this.lastSeq = 0,
    this.mediaJobs = const [],
    this.filmJobs = const [],
    this.filmDrafts = const {},
    this.filmPendingRequests = const {},
    this.pinned = false,
  });
  final String id;
  final String title;
  final DemoSessionKind kind;
  final List<String> members;
  final List<String> roles;
  final List<DemoMessage> messages;
  final int unread;
  final String time;
  final DateTime? updatedAt;
  final String direction;
  final String positioning;
  final Map<String, String> accountPreferences;
  final DemoCreativeMemory creativeMemory;
  final List<String> capabilities;
  final Map<String, String> memberNames;
  final Map<String, String> memberInstructions;
  final Map<String, String> memberAvatars;
  final Map<String, int> memberColors;
  final Map<String, List<String>> memberCapabilities;
  final Map<String, List<String>> memberSkills;
  final Map<String, String> memberBotIds;
  final String workMode;
  final String activeMemberId;
  final Map<String, DemoRoleProfile> roleProfiles;
  final int configRevision;
  final String configurationStatus;
  final int serverRevision;
  final int lastSeq;
  final List<DemoMediaJob> mediaJobs;
  final List<DemoStyleFilmJob> filmJobs;

  /// Unsent selections are local to this device and never enter configuration.
  final Map<String, DemoStyleFilmSelection> filmDrafts;
  final Map<String, DemoStyleFilmPendingRequest> filmPendingRequests;
  final bool pinned;

  /// A member inherits conversation capabilities until it has a local override.
  List<String> capabilitiesFor(String memberId) =>
      List.unmodifiable(memberCapabilities[memberId] ?? capabilities);

  List<String> skillsFor(String memberId) =>
      List.unmodifiable(memberSkills[memberId] ?? const <String>[]);

  String botIdFor(String memberId) {
    final saved = memberBotIds[memberId];
    if (saved != null && saved.isNotEmpty) return saved;
    final customized =
        (memberNames[memberId]?.trim().isNotEmpty ?? false) ||
        (memberInstructions[memberId]?.trim().isNotEmpty ?? false) ||
        (memberAvatars[memberId]?.isNotEmpty ?? false) ||
        memberColors.containsKey(memberId);
    return customized ? 'legacy:$id:$memberId' : 'builtin:$memberId';
  }

  bool get rolesReady =>
      roles.every((roleId) => roleProfiles[roleId]?.isReady ?? false);

  DemoSession copyWith({
    String? title,
    List<String>? members,
    List<String>? roles,
    List<DemoMessage>? messages,
    int? unread,
    String? time,
    DateTime? updatedAt,
    String? direction,
    String? positioning,
    Map<String, String>? accountPreferences,
    DemoCreativeMemory? creativeMemory,
    List<String>? capabilities,
    Map<String, String>? memberNames,
    Map<String, String>? memberInstructions,
    Map<String, String>? memberAvatars,
    Map<String, int>? memberColors,
    Map<String, List<String>>? memberCapabilities,
    Map<String, List<String>>? memberSkills,
    Map<String, String>? memberBotIds,
    String? workMode,
    String? activeMemberId,
    Map<String, DemoRoleProfile>? roleProfiles,
    int? configRevision,
    String? configurationStatus,
    int? serverRevision,
    int? lastSeq,
    List<DemoMediaJob>? mediaJobs,
    List<DemoStyleFilmJob>? filmJobs,
    Map<String, DemoStyleFilmSelection>? filmDrafts,
    Map<String, DemoStyleFilmPendingRequest>? filmPendingRequests,
    bool? pinned,
  }) => DemoSession(
    id: id,
    title: title ?? this.title,
    kind: kind,
    members: members ?? this.members,
    roles: roles ?? this.roles,
    messages: messages ?? this.messages,
    unread: unread ?? this.unread,
    time: time ?? this.time,
    updatedAt: updatedAt ?? this.updatedAt,
    direction: direction ?? this.direction,
    positioning: positioning ?? this.positioning,
    accountPreferences: accountPreferences ?? this.accountPreferences,
    creativeMemory: creativeMemory ?? this.creativeMemory,
    capabilities: capabilities ?? this.capabilities,
    memberNames: memberNames ?? this.memberNames,
    memberInstructions: memberInstructions ?? this.memberInstructions,
    memberAvatars: memberAvatars ?? this.memberAvatars,
    memberColors: memberColors ?? this.memberColors,
    memberCapabilities: memberCapabilities ?? this.memberCapabilities,
    memberSkills: memberSkills ?? this.memberSkills,
    memberBotIds: memberBotIds ?? this.memberBotIds,
    workMode: workMode ?? this.workMode,
    activeMemberId: activeMemberId ?? this.activeMemberId,
    roleProfiles: roleProfiles ?? this.roleProfiles,
    configRevision: configRevision ?? this.configRevision,
    configurationStatus: configurationStatus ?? this.configurationStatus,
    serverRevision: serverRevision ?? this.serverRevision,
    lastSeq: lastSeq ?? this.lastSeq,
    mediaJobs: mediaJobs ?? this.mediaJobs,
    filmJobs: filmJobs ?? this.filmJobs,
    filmDrafts: filmDrafts ?? this.filmDrafts,
    filmPendingRequests: filmPendingRequests ?? this.filmPendingRequests,
    pinned: pinned ?? this.pinned,
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
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    'direction': direction,
    'positioning': positioning,
    'accountPreferences': accountPreferences,
    'creativeMemory': creativeMemory.toJson(),
    'capabilities': capabilities,
    'memberNames': memberNames,
    'memberInstructions': memberInstructions,
    'memberAvatars': memberAvatars,
    'memberColors': memberColors,
    'memberCapabilities': memberCapabilities,
    'memberSkills': memberSkills,
    'memberBotIds': {for (final member in members) member: botIdFor(member)},
    'workMode': workMode,
    'activeMemberId': activeMemberId,
    'roleProfiles': roleProfiles.map(
      (roleId, profile) => MapEntry(roleId, profile.toJson()),
    ),
    'configRevision': configRevision,
    'configurationStatus': configurationStatus,
    'serverRevision': serverRevision,
    'lastSeq': lastSeq,
    'mediaJobs': mediaJobs.map((job) => job.toJson()).toList(),
    'filmJobs': filmJobs.map((job) => job.toJson()).toList(),
    if (filmDrafts.isNotEmpty)
      'filmDrafts': filmDrafts.map(
        (id, selection) => MapEntry(id, selection.toJson()),
      ),
    if (filmPendingRequests.isNotEmpty)
      'filmPendingRequests': filmPendingRequests.map(
        (id, request) => MapEntry(id, request.toJson()),
      ),
    'pinned': pinned,
  };
  factory DemoSession.fromJson(Map<String, Object?> json) => DemoSession(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: DemoSessionKind.values.byName(json['kind'] as String),
    members: (json['members'] as List).cast<String>(),
    roles: (json['roles'] as List).cast<String>(),
    messages: (json['messages'] as List)
        .map((m) => DemoMessage.fromJson(Map<String, Object?>.from(m as Map)))
        .toList(),
    unread: json['unread'] as int,
    time: json['time'] as String,
    updatedAt: _parseDateTime(json['updatedAt']),
    direction: json['direction'] as String,
    positioning: json['positioning'] as String,
    accountPreferences: Map<String, String>.from(
      json['accountPreferences'] as Map? ?? {},
    ),
    creativeMemory: DemoCreativeMemory.fromJson(json['creativeMemory']),
    capabilities: List<String>.from(
      json['capabilities'] as List? ?? defaultCapabilities,
    ),
    memberNames: Map<String, String>.from(json['memberNames'] as Map? ?? {}),
    memberInstructions: Map<String, String>.from(
      json['memberInstructions'] as Map? ?? {},
    ),
    memberAvatars: Map<String, String>.from(
      json['memberAvatars'] as Map? ?? {},
    ),
    memberColors: (json['memberColors'] as Map? ?? {}).map(
      (key, value) => MapEntry(
        key as String,
        value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0,
      ),
    ),
    memberCapabilities: (json['memberCapabilities'] as Map? ?? {}).map(
      (key, value) => MapEntry(key as String, (value as List).cast<String>()),
    ),
    memberSkills: (json['memberSkills'] as Map? ?? {}).map(
      (key, value) => MapEntry(key as String, (value as List).cast<String>()),
    ),
    memberBotIds: Map<String, String>.from(json['memberBotIds'] as Map? ?? {}),
    workMode: json['workMode'] as String? ?? 'onDemand',
    activeMemberId:
        json['activeMemberId'] as String? ??
        ((json['members'] as List?)?.firstOrNull?.toString() ?? 'popi'),
    roleProfiles: (json['roleProfiles'] as Map? ?? {}).map(
      (key, value) => MapEntry(
        key as String,
        DemoRoleProfile.fromJson(Map<String, Object?>.from(value as Map)),
      ),
    ),
    configRevision: (json['configRevision'] as num?)?.toInt() ?? 0,
    configurationStatus: json['configurationStatus'] as String? ?? 'legacy',
    serverRevision: (json['serverRevision'] as num?)?.toInt() ?? 0,
    lastSeq: (json['lastSeq'] as num?)?.toInt() ?? 0,
    mediaJobs: (json['mediaJobs'] as List? ?? const [])
        .whereType<Map>()
        .map((job) => DemoMediaJob.fromJson(Map<String, Object?>.from(job)))
        .toList(),
    filmJobs: (json['filmJobs'] as List? ?? const [])
        .whereType<Map>()
        .map((job) => DemoStyleFilmJob.fromJson(Map<String, Object?>.from(job)))
        .toList(),
    filmDrafts: (json['filmDrafts'] as Map? ?? {}).map(
      (key, value) => MapEntry(
        key as String,
        DemoStyleFilmSelection.fromJson(
          Map<String, Object?>.from(value as Map),
        ),
      ),
    ),
    filmPendingRequests: (json['filmPendingRequests'] as Map? ?? {}).map(
      (key, value) => MapEntry(
        key as String,
        DemoStyleFilmPendingRequest.fromJson(
          Map<String, Object?>.from(value as Map),
        ),
      ),
    ),
    pinned: json['pinned'] as bool? ?? false,
  );
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

@immutable
class DemoDocumentMetadata {
  const DemoDocumentMetadata({
    required this.format,
    this.status = 'ready',
    this.pageCount,
    this.slideCount,
    this.textCharacters = 0,
    this.truncated = false,
    this.ocrUsed = false,
    this.pageCountEstimated = false,
  });
  final String format;
  final String status;
  final int? pageCount;
  final int? slideCount;
  final int textCharacters;
  final bool truncated;
  final bool ocrUsed;
  final bool pageCountEstimated;
  bool get isReady => status == 'ready';

  Map<String, Object?> toJson() => {
    'format': format,
    'status': status,
    if (pageCount != null) 'pageCount': pageCount,
    if (slideCount != null) 'slideCount': slideCount,
    'textCharacters': textCharacters,
    'truncated': truncated,
    if (ocrUsed) 'ocrUsed': ocrUsed,
    if (pageCountEstimated) 'pageCountEstimated': pageCountEstimated,
  };
  factory DemoDocumentMetadata.fromJson(Map<String, Object?> json) =>
      DemoDocumentMetadata(
        format: json['format']?.toString() ?? '',
        status: json['status']?.toString() ?? 'ready',
        pageCount: (json['pageCount'] as num?)?.toInt(),
        slideCount: (json['slideCount'] as num?)?.toInt(),
        textCharacters: (json['textCharacters'] as num?)?.toInt() ?? 0,
        truncated: json['truncated'] == true,
        ocrUsed: json['ocrUsed'] == true,
        pageCountEstimated: json['pageCountEstimated'] == true,
      );
}

@immutable
class DemoAsset {
  const DemoAsset({
    required this.id,
    required this.title,
    required this.kind,
    required this.cover,
    this.sessionId,
    this.body = '',
    this.media = '',
    this.contentUrl = '',
    this.posterUrl = '',
    this.thumbnailUrl = '',
    this.jobId = '',
    this.runId = '',
    this.memberId = '',
    this.configRevision = 0,
    this.mimeType = '',
    this.sha256 = '',
    this.sizeBytes = 0,
    this.width = 0,
    this.height = 0,
    this.durationSeconds = 0,
    this.hasAudio = false,
    this.createdAt = '',
    this.document,
    this.businessAssetId = '',
  });
  final String businessAssetId;
  final String id;
  final String title;
  final DemoAssetKind kind;
  final String cover;
  final String? sessionId;
  final String body;
  final String media;
  final String contentUrl;
  final String posterUrl;
  final String thumbnailUrl;
  final String jobId;
  final String runId;
  final String memberId;
  final int configRevision;
  final String mimeType;
  final String sha256;
  final int sizeBytes;
  final int width;
  final int height;
  final double durationSeconds;
  final bool hasAudio;
  final String createdAt;
  final DemoDocumentMetadata? document;

  bool get isRemote => contentUrl.isNotEmpty;
  bool get isDocument =>
      document != null ||
      const {
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      }.contains(mimeType);

  DemoAsset copyWith({String? title}) => DemoAsset(
    id: id,
    businessAssetId: businessAssetId,
    title: title ?? this.title,
    kind: kind,
    cover: cover,
    sessionId: sessionId,
    body: body,
    media: media,
    contentUrl: contentUrl,
    posterUrl: posterUrl,
    thumbnailUrl: thumbnailUrl,
    jobId: jobId,
    runId: runId,
    memberId: memberId,
    configRevision: configRevision,
    mimeType: mimeType,
    sha256: sha256,
    sizeBytes: sizeBytes,
    width: width,
    height: height,
    durationSeconds: durationSeconds,
    hasAudio: hasAudio,
    createdAt: createdAt,
    document: document,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    if (businessAssetId.isNotEmpty) 'businessAssetId': businessAssetId,
    'title': title,
    'kind': kind.name,
    'cover': businessAssetId.isNotEmpty ? '' : cover,
    'sessionId': sessionId,
    'body': body,
    'media': businessAssetId.isNotEmpty ? '' : media,
    if (contentUrl.isNotEmpty)
      'contentUrl': businessAssetId.isNotEmpty
          ? '/api_agent/v2/assets/$id/content'
          : contentUrl,
    if (posterUrl.isNotEmpty) 'posterUrl': posterUrl,
    if (thumbnailUrl.isNotEmpty) 'thumbnailUrl': thumbnailUrl,
    if (jobId.isNotEmpty) 'jobId': jobId,
    if (runId.isNotEmpty) 'runId': runId,
    if (memberId.isNotEmpty) 'memberId': memberId,
    'configRevision': configRevision,
    if (mimeType.isNotEmpty) 'mimeType': mimeType,
    if (sha256.isNotEmpty) 'sha256': sha256,
    'sizeBytes': sizeBytes,
    'width': width,
    'height': height,
    if (kind == DemoAssetKind.video || kind == DemoAssetKind.audio)
      'durationSeconds': durationSeconds,
    if (kind == DemoAssetKind.video || kind == DemoAssetKind.audio)
      'hasAudio': hasAudio,
    if (createdAt.isNotEmpty) 'createdAt': createdAt,
    if (document != null) 'document': document!.toJson(),
  };
  factory DemoAsset.fromJson(Map<String, Object?> json) => DemoAsset(
    id: json['id'] as String,
    businessAssetId: json['businessAssetId']?.toString() ?? '',
    title: json['title'] as String,
    kind: DemoAssetKind.values.byName(json['kind'] as String),
    cover: json['cover']?.toString() ?? json['contentUrl']?.toString() ?? '',
    sessionId: json['sessionId'] as String?,
    body: json['body']?.toString() ?? '',
    media: json['media']?.toString() ?? '',
    contentUrl: json['contentUrl']?.toString() ?? '',
    posterUrl: json['posterUrl']?.toString() ?? '',
    thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
    jobId: json['jobId']?.toString() ?? '',
    runId: json['runId']?.toString() ?? '',
    memberId: json['memberId']?.toString() ?? '',
    configRevision: (json['configRevision'] as num?)?.toInt() ?? 0,
    mimeType: json['mimeType']?.toString() ?? '',
    sha256: json['sha256']?.toString() ?? '',
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
    hasAudio: json['hasAudio'] as bool? ?? false,
    createdAt: json['createdAt']?.toString() ?? '',
    document: json['document'] is Map
        ? DemoDocumentMetadata.fromJson(
            Map<String, Object?>.from(json['document'] as Map),
          )
        : null,
  );
}

enum DemoRoleReferenceAvailability { pending, localOnly, ready }

/// Reports whether every linked visual reference can reach a cloud model.
///
/// Uploaded assets stay private in the product. A configured Harness can mint
/// a bounded provider URL for them at generation time without persisting that
/// temporary URL in the role profile.
DemoRoleReferenceAvailability demoRoleReferenceAvailability({
  required DemoRoleProfile? profile,
  required Iterable<DemoAsset> assets,
  required bool referencePublishingConfigured,
}) {
  if (profile == null) return DemoRoleReferenceAvailability.pending;
  final publicUrls = profile.referenceImageUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList();
  final byId = {for (final asset in assets) asset.id: asset};
  final referencedAssets = [
    for (final id in profile.referenceAssetIds)
      if (byId[id] case final asset?) asset,
  ];
  if (referencedAssets.length != profile.referenceAssetIds.length) {
    return DemoRoleReferenceAvailability.pending;
  }
  if (publicUrls.isEmpty && referencedAssets.isEmpty) {
    return DemoRoleReferenceAvailability.pending;
  }
  final assetsReady = referencedAssets.every(
    (asset) =>
        asset.jobId.trim().isNotEmpty ||
        (referencePublishingConfigured &&
            asset.kind == DemoAssetKind.image &&
            asset.isRemote &&
            asset.sha256.trim().isNotEmpty),
  );
  if (assetsReady) return DemoRoleReferenceAvailability.ready;
  return DemoRoleReferenceAvailability.localOnly;
}

@immutable
class DemoCharacter {
  const DemoCharacter(this.id, this.name, this.image);
  final String id;
  final String name;
  final String image;
}
