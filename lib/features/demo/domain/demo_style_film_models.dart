import 'package:flutter/foundation.dart';

const demoStyleFilmSkillId = 'lemo-opuscar';

/// Keeps an uncertain film submission idempotent after this device restarts.
@immutable
class DemoStyleFilmPendingRequest {
  const DemoStyleFilmPendingRequest({
    required this.body,
    required this.clientRequestId,
  });
  final String body;
  final String clientRequestId;
  Map<String, Object?> toJson() => {
    'body': body,
    'clientRequestId': clientRequestId,
  };
  factory DemoStyleFilmPendingRequest.fromJson(Map<String, Object?> json) =>
      DemoStyleFilmPendingRequest(
        body: json['body'] as String,
        clientRequestId: json['clientRequestId'] as String,
      );
}

/// A device-local selection; only its arguments are sent to the film service.
@immutable
class DemoStyleFilmSelection {
  const DemoStyleFilmSelection({
    required this.styleId,
    this.durationSeconds = 15,
    this.aspectRatio = '9:16',
    this.storyboardReview = true,
    this.soundtrack = 'none',
    this.styleNameZh = '',
    this.styleNameEn = '',
  });

  final String styleId;
  final int durationSeconds;
  final String aspectRatio;
  final bool storyboardReview;
  final String soundtrack;
  final String styleNameZh;
  final String styleNameEn;

  bool get isValid =>
      RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(styleId) &&
      const [15, 30].contains(durationSeconds) &&
      const ['9:16', '16:9', '1:1'].contains(aspectRatio) &&
      storyboardReview &&
      const ['none', 'music'].contains(soundtrack);

  DemoStyleFilmSelection copyWith({
    String? styleId,
    int? durationSeconds,
    String? aspectRatio,
    bool? storyboardReview,
    String? soundtrack,
    String? styleNameZh,
    String? styleNameEn,
  }) => DemoStyleFilmSelection(
    styleId: styleId ?? this.styleId,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    storyboardReview: storyboardReview ?? this.storyboardReview,
    soundtrack: soundtrack ?? this.soundtrack,
    styleNameZh: styleNameZh ?? this.styleNameZh,
    styleNameEn: styleNameEn ?? this.styleNameEn,
  );

  Map<String, Object?> toArguments() => {
    'styleId': styleId,
    'durationSeconds': durationSeconds,
    'aspectRatio': aspectRatio,
    'storyboardReview': storyboardReview,
    'soundtrack': soundtrack,
  };

  Map<String, Object?> toJson() => {
    ...toArguments(),
    if (styleNameZh.isNotEmpty) 'styleNameZh': styleNameZh,
    if (styleNameEn.isNotEmpty) 'styleNameEn': styleNameEn,
  };

  factory DemoStyleFilmSelection.fromJson(Map<String, Object?> json) =>
      DemoStyleFilmSelection(
        styleId: _text(json['styleId']),
        durationSeconds: _integer(json['durationSeconds'], 15),
        aspectRatio: _text(json['aspectRatio'], '9:16'),
        storyboardReview: json['storyboardReview'] != false,
        soundtrack: _text(json['soundtrack'], 'none'),
        styleNameZh: _text(json['styleNameZh']),
        styleNameEn: _text(json['styleNameEn']),
      );
}

@immutable
class DemoStyleFilmInvocation {
  const DemoStyleFilmInvocation({required this.selection});

  final DemoStyleFilmSelection selection;
  String get skillId => demoStyleFilmSkillId;
  Map<String, Object?> toJson() => {
    'skillId': skillId,
    'arguments': selection.toArguments(),
  };
}

@immutable
class DemoStyleFilmSupports {
  const DemoStyleFilmSupports({
    this.durations = const [],
    this.aspectRatios = const [],
    this.soundtracks = const [],
  });

  final List<int> durations;
  final List<String> aspectRatios;
  final List<String> soundtracks;

  bool accepts(DemoStyleFilmSelection selection) =>
      selection.isValid &&
      durations.contains(selection.durationSeconds) &&
      aspectRatios.contains(selection.aspectRatio) &&
      soundtracks.contains(selection.soundtrack);

  factory DemoStyleFilmSupports.fromJson(Object? value) {
    final json = _map(value);
    return DemoStyleFilmSupports(
      durations: _list(
        json['durations'],
      ).whereType<num>().map((n) => n.toInt()).toList(),
      aspectRatios: _strings(json['aspectRatios']),
      soundtracks: _strings(json['soundtracks']),
    );
  }
}

@immutable
class DemoStyleFilmStyle {
  const DemoStyleFilmStyle({
    required this.id,
    this.nameZh = '',
    this.nameEn = '',
    this.categoryId = '',
    this.categoryZh = '',
    this.categoryEn = '',
    this.descriptionZh = '',
    this.descriptionEn = '',
    this.posterUrl = '',
    this.ready = false,
    this.supported = false,
    this.reasonUnavailable = '',
    this.reasonUnavailableCode = '',
  });

  final String id;
  final String nameZh;
  final String nameEn;
  final String categoryId;
  final String categoryZh;
  final String categoryEn;
  final String descriptionZh;
  final String descriptionEn;
  final String posterUrl;
  final bool ready;
  final bool supported;
  final String reasonUnavailable;
  final String reasonUnavailableCode;

  String nameFor(String languageCode) => languageCode == 'zh'
      ? (nameZh.isEmpty ? nameEn : nameZh)
      : (nameEn.isEmpty ? nameZh : nameEn);

  factory DemoStyleFilmStyle.fromJson(Map<String, Object?> json) =>
      DemoStyleFilmStyle(
        id: _text(json['id']),
        nameZh: _text(json['nameZh']),
        nameEn: _text(json['nameEn']),
        categoryId: _text(json['categoryId']),
        categoryZh: _text(json['categoryZh']),
        categoryEn: _text(json['categoryEn']),
        descriptionZh: _text(json['descriptionZh']),
        descriptionEn: _text(json['descriptionEn']),
        posterUrl: _text(json['posterUrl']),
        ready: json['ready'] == true,
        supported:
            json['supported'] == true ||
            (json['supported'] == null && json['ready'] == true),
        reasonUnavailable: _text(json['reasonUnavailable']),
        reasonUnavailableCode: _text(json['reasonUnavailableCode']),
      );
}

@immutable
class DemoStyleFilmCategory {
  const DemoStyleFilmCategory({
    required this.id,
    this.nameZh = '',
    this.nameEn = '',
  });

  final String id;
  final String nameZh;
  final String nameEn;

  String nameFor(String languageCode) => languageCode == 'zh'
      ? (nameZh.isEmpty ? nameEn : nameZh)
      : (nameEn.isEmpty ? nameZh : nameEn);

  factory DemoStyleFilmCategory.fromJson(Map<String, Object?> json) =>
      DemoStyleFilmCategory(
        id: _text(json['id']),
        nameZh: _text(json['nameZh']),
        nameEn: _text(json['nameEn']),
      );
}

@immutable
class DemoStyleFilmCatalog {
  const DemoStyleFilmCatalog({
    this.skillId = demoStyleFilmSkillId,
    this.catalogVersion = '',
    this.upstreamCommit = '',
    this.available = false,
    this.reasonUnavailable = '',
    this.reasonUnavailableCode = '',
    this.supports = const DemoStyleFilmSupports(),
    this.list = const [],
    this.categories = const [],
    int? readyCount,
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.pageCount = 0,
  }) : _readyCount = readyCount;

  final String skillId;
  final String catalogVersion;
  final String upstreamCommit;
  final bool available;
  final String reasonUnavailable;
  final String reasonUnavailableCode;
  final DemoStyleFilmSupports supports;
  final List<DemoStyleFilmStyle> list;
  final List<DemoStyleFilmCategory> categories;
  final int? _readyCount;

  /// Older servers expose only the current page; new servers send the filtered total.
  int get readyCount =>
      _readyCount ?? list.where((style) => style.ready).length;
  final int page;
  final int pageSize;
  final int total;
  final int pageCount;

  factory DemoStyleFilmCatalog.fromJson(Map<String, Object?> json) {
    final page = _map(json['pageInfo']);
    return DemoStyleFilmCatalog(
      skillId: _text(json['skillId'], demoStyleFilmSkillId),
      catalogVersion: _text(json['catalogVersion']),
      upstreamCommit: _text(json['upstreamCommit']),
      available: json['available'] == true,
      reasonUnavailable: _text(json['reasonUnavailable']),
      reasonUnavailableCode: _text(json['reasonUnavailableCode']),
      supports: DemoStyleFilmSupports.fromJson(json['supports']),
      readyCount: json['readyCount'] is num
          ? (json['readyCount'] as num).toInt()
          : null,
      categories: _list(json['categories'])
          .whereType<Map>()
          .map((item) => DemoStyleFilmCategory.fromJson(_map(item)))
          .toList(),
      list: _list(json['list'])
          .whereType<Map>()
          .map((item) => DemoStyleFilmStyle.fromJson(_map(item)))
          .toList(),
      page: _integer(page['page'], 1),
      pageSize: _integer(page['pageSize'], 20),
      total: _integer(page['total']),
      pageCount: _integer(page['pageCount']),
    );
  }
}

@immutable
class DemoStyleFilmStoryboard {
  const DemoStyleFilmStoryboard({
    required this.id,
    this.title = '',
    this.description = '',
    this.startSeconds = 0,
    this.durationSeconds = 0,
    this.previewAssetId = '',
    this.previewUrl = '',
  });
  final String id;
  final String title;
  final String description;
  final double startSeconds;
  final double durationSeconds;
  final String previewAssetId;
  final String previewUrl;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'startSeconds': startSeconds,
    'durationSeconds': durationSeconds,
    'previewAssetId': previewAssetId,
    'previewUrl': previewUrl,
  };
  factory DemoStyleFilmStoryboard.fromJson(Map<String, Object?> json) =>
      DemoStyleFilmStoryboard(
        id: _text(json['id']),
        title: _text(json['title']),
        description: _text(json['description']),
        startSeconds: _number(json['startSeconds']),
        durationSeconds: _number(json['durationSeconds']),
        previewAssetId: _text(json['previewAssetId']),
        previewUrl: _text(json['previewUrl']),
      );
}

/// A server-authoritative job, independent of the text run's lifetime.
@immutable
class DemoStyleFilmJob {
  const DemoStyleFilmJob({
    required this.jobId,
    this.sessionId = '',
    this.runId = '',
    this.memberId = '',
    this.botId = '',
    this.memberName = '',
    this.configRevision = 0,
    this.styleId = '',
    this.styleNameZh = '',
    this.styleNameEn = '',
    this.catalogVersion = '',
    this.arguments = const DemoStyleFilmSelection(styleId: ''),
    this.title = '',
    this.revision = 0,
    this.state = '',
    this.stage = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.storyboard = const [],
    this.assetIds = const [],
    this.allowedActions = const [],
    this.error = const {},
  });
  final String jobId, sessionId, runId, memberId, botId, memberName;
  final int configRevision;
  final String styleId, styleNameZh, styleNameEn, catalogVersion;
  final DemoStyleFilmSelection arguments;
  final String title;
  final int revision;
  final String state, stage, createdAt, updatedAt;
  final List<DemoStyleFilmStoryboard> storyboard;
  final List<String> assetIds, allowedActions;
  final Map<String, Object?> error;

  bool get isFailed => state.startsWith('failed');
  bool get isCompleted => state == 'completed';
  bool get isAwaitingReview => state == 'awaiting_storyboard';
  bool get isPending =>
      !isFailed && !isCompleted && state != 'cancelled' && state != 'stopped';
  bool get needsObservation => isPending && !isAwaitingReview;

  Map<String, Object?> toJson() => {
    'jobId': jobId,
    'sessionId': sessionId,
    'runId': runId,
    'memberId': memberId,
    'botId': botId,
    'memberName': memberName,
    'configRevision': configRevision,
    'styleId': styleId,
    'styleNameZh': styleNameZh,
    'styleNameEn': styleNameEn,
    'catalogVersion': catalogVersion,
    'arguments': arguments.toArguments(),
    'title': title,
    'revision': revision,
    'state': state,
    'stage': stage,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'storyboard': storyboard.map((item) => item.toJson()).toList(),
    'assetIds': assetIds,
    'allowedActions': allowedActions,
    if (error.isNotEmpty) 'error': error,
  };

  factory DemoStyleFilmJob.fromJson(Map<String, Object?> json) =>
      DemoStyleFilmJob(
        jobId: _text(json['jobId']),
        sessionId: _text(json['sessionId']),
        runId: _text(json['runId']),
        memberId: _text(json['memberId']),
        botId: _text(json['botId']),
        memberName: _text(json['memberName']),
        configRevision: _integer(json['configRevision']),
        styleId: _text(json['styleId']),
        styleNameZh: _text(json['styleNameZh']),
        styleNameEn: _text(json['styleNameEn']),
        catalogVersion: _text(json['catalogVersion']),
        arguments: DemoStyleFilmSelection.fromJson(_map(json['arguments'])),
        title: _text(json['title']),
        revision: _integer(json['revision']),
        state: _text(json['state']),
        stage: _text(json['stage']),
        createdAt: _text(json['createdAt']),
        updatedAt: _text(json['updatedAt']),
        storyboard: _list(json['storyboard'])
            .whereType<Map>()
            .map((item) => DemoStyleFilmStoryboard.fromJson(_map(item)))
            .toList(),
        assetIds: _strings(json['assetIds']),
        allowedActions: _strings(json['allowedActions']),
        error: _map(json['error']),
      );
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const {};
List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];
List<String> _strings(Object? value) =>
    _list(value).whereType<String>().toList();
String _text(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;
int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;
double _number(Object? value) => value is num ? value.toDouble() : 0;
