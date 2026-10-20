import '../../assets/domain/library_role.dart';
import 'role_generation.dart';

Map<String, Object?> homeObject(Object? value) {
  if (value is! Map) throw const FormatException('Invalid home response');
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> homeObjects(Object? value) =>
    value is List ? value.map(homeObject).toList() : const [];

String homeId(Object? value) {
  final id = value?.toString() ?? '';
  if (id.isEmpty) throw const FormatException('Missing home identity');
  return id;
}

/// Server-owned creation context shared by role selection and generation.
class HomeCreation {
  HomeCreation.fromJson(Map<String, Object?> json)
    : creation = homeObject(json['creation']),
      revision = homeObject(json['currentRevision']),
      editable = json['editable'] == true,
      topics = [
        ...homeObjects(json['topics']),
        ...homeObjects(json['customTopics']),
      ].map(HomeTopic.fromJson).toList(),
      selectedTopic = json['selectedTopic'] == null
          ? null
          : HomeTopic.fromJson(homeObject(json['selectedTopic'])),
      task = json['task'] == null
          ? null
          : HomeTask.fromJson(homeObject(json['task'])) {
    homeId(creation['id']);
    homeId(creation['accountId']);
    homeId(creation['sessionId']);
    if (creation['revision'] is! int) {
      throw const FormatException('Missing creation revision');
    }
    if (selectedTopic != null &&
        !topics.any((topic) => topic.id == selectedTopic!.id)) {
      topics.add(selectedTopic!);
    }
  }

  final Map<String, Object?> creation;
  final Map<String, Object?> revision;
  final bool editable;
  final List<HomeTopic> topics;
  final HomeTopic? selectedTopic;
  final HomeTask? task;
  String get id => homeId(creation['id']);
  String get accountId => homeId(creation['accountId']);
  String get sessionId => homeId(creation['sessionId']);
  int get version => creation['revision'] as int;
  List<LibraryRole> get cast => homeObjects(
    revision['cast'],
  ).map((item) => LibraryRole.fromJson(item)).toList();
  // Edit the fixed source version, rather than the display-only profile projection.
  List<LibraryRole> get castForEditing => homeObjects(revision['cast'])
      .map(
        (item) => LibraryRole.fromJson({
          ...item,
          if (item['profileVersion'] is Map)
            'profile': homeObject(item['profileVersion'])['profile'],
        }),
      )
      .toList();
  HomeConfig? get config {
    final value = homeObject(revision['specs'])['homeConfig'];
    return value == null ? null : HomeConfig.fromJson(homeObject(value));
  }
}

class HomeTopic {
  HomeTopic.fromJson(Map<String, Object?> json)
    : id = homeId(json['id']),
      title = json['title']?.toString() ?? '',
      story = (json['story'] ?? json['summary'])?.toString() ?? '';
  final String id;
  final String title;
  final String story;
}

class HomeConfig {
  const HomeConfig({required this.modelId, required this.params});
  HomeConfig.fromJson(Map<String, Object?> json)
    : modelId = homeId(json['modelId']),
      params = homeObject(json['params']);
  final String modelId;
  final Map<String, Object?> params;
  Map<String, Object?> toJson() => {'modelId': modelId, 'params': params};

  bool matches(HomeConfig? other) =>
      other != null &&
      modelId == other.modelId &&
      params.length == other.params.length &&
      params.entries.every(
        (entry) =>
            other.params.containsKey(entry.key) &&
            other.params[entry.key] == entry.value,
      );
}

class HomeModel {
  HomeModel.fromJson(Map<String, Object?> json)
    : id = homeId(json['id']),
      name = json['name']?.toString() ?? '',
      description = json['description'] as String?,
      available = json['available'] == true,
      mediaType = json['mediaType']?.toString() ?? '',
      isDefault = json['isDefault'] == true,
      referenceSchema = json['referenceSchema'] is Map
          ? homeObject(json['referenceSchema'])
          : const {},
      parameters = homeObjects(
        json['parameters'],
      ).map(HomeParameter.fromJson).toList();
  final String id;
  final String name;
  final String? description;
  final bool available;
  final String mediaType;
  final bool isDefault;
  final Map<String, Object?> referenceSchema;
  final List<HomeParameter> parameters;

  bool acceptsImageReferences(int count) {
    final image = referenceSchema['image'];
    if (image is! Map) return true;
    return (count == 0 || image['supported'] == true) &&
        count >= (image['min'] as num? ?? 0) &&
        (image['max'] is! num || count <= (image['max'] as num));
  }

  HomeConfig get defaultConfig => HomeConfig(
    modelId: id,
    params: {
      for (final parameter in parameters)
        if (parameter.defaultValue != null)
          parameter.name: parameter.defaultValue,
    },
  );

  /// Replaces legacy automatic durations with a value allowed by this model.
  HomeConfig withExplicitDurations(HomeConfig config) {
    final params = {...config.params};
    for (final parameter in parameters) {
      if (!parameter.name.toLowerCase().contains('duration') ||
          params[parameter.name] is num) {
        continue;
      }
      final values =
          parameter.options
              .map((option) => option.value)
              .whereType<num>()
              .toList()
            ..sort();
      for (final candidate in [
        parameter.defaultValue,
        ...values,
        parameter.min,
      ]) {
        if (candidate is! num || !candidate.isFinite) continue;
        final value = parameter.type == 'integer'
            ? candidate.toInt()
            : candidate;
        if (!parameter.accepts(value)) continue;
        params[parameter.name] = value;
        break;
      }
    }
    return HomeConfig(modelId: config.modelId, params: params);
  }

  bool accepts(HomeConfig config) =>
      config.modelId == id &&
      parameters.every(
        (parameter) => parameter.accepts(config.params[parameter.name]),
      );
}

class HomeParameter {
  HomeParameter.fromJson(Map<String, Object?> json)
    : name = homeId(json['name']),
      label = json['label']?.toString() ?? '',
      type = json['type']?.toString() ?? 'string',
      required = json['required'] == true,
      defaultValue = json['default'],
      min = json['min'] as num?,
      max = json['max'] as num?,
      step = json['step'] as num?,
      options = _options(json['options']);
  final String name;
  final String label;
  final String type;
  final bool required;
  final Object? defaultValue;
  final num? min;
  final num? max;
  final num? step;
  final List<({String label, Object value})> options;

  static List<({String label, Object value})> _options(Object? input) =>
      input is List
      ? input.map((item) {
          final Object? value = item is Map ? item['value'] : item;
          if (value is! String && value is! num && value is! bool) {
            throw const FormatException('Invalid model option');
          }
          return (
            label: item is Map
                ? (item['label'] ?? value).toString()
                : value.toString(),
            value: value!,
          );
        }).toList()
      : const [];

  bool accepts(Object? value) {
    if (value == null || value == '') return !required;
    if (options.isNotEmpty) {
      return options.any((option) => option.value == value);
    }
    return switch (type) {
      'boolean' => value is bool,
      'number' => value is num && _acceptsNumber(value),
      'integer' => value is int && _acceptsNumber(value),
      _ => value is String,
    };
  }

  bool _acceptsNumber(num value) {
    if (!value.isFinite ||
        (min != null && value < min!) ||
        (max != null && value > max!)) {
      return false;
    }
    if (step != null && step! > 0) {
      final count = (value - (min ?? 0)) / step!;
      if ((count - count.round()).abs() > 0.00000001) return false;
    }
    return true;
  }
}

class HomeTask {
  HomeTask.fromJson(Map<String, Object?> json)
    : id = homeId(json['id'] ?? json['taskId']),
      state = homeId(json['state'] ?? json['initialState']),
      intent = (json['intent'] ?? json['controlIntent'] ?? 'run').toString(),
      revision = (json['revision'] ?? json['stateVersion'] ?? 0) as int,
      lock = json['lock']?.toString(),
      allowedActions = (json['allowedActions'] as List? ?? const [])
          .cast<String>(),
      confirmationPending = json['confirmationPending'] == true,
      confirmationReason = json['confirmationReason'] as String?,
      steps = homeObjects(json['steps'] ?? json['stages']);
  final String id;
  final String state;
  final String intent;
  final int revision;
  final String? lock;
  final List<String> allowedActions;
  final bool confirmationPending;
  final String? confirmationReason;
  final List<Map<String, Object?>> steps;
  String? get videoMediaId {
    for (final step in steps) {
      final output = step['output'];
      if (output is Map &&
          (step['key'] == 'video' || output['kind'] == 'video')) {
        final id = output['mediaId']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }
    return null;
  }

  bool get canConfirmVideo =>
      state == 'awaiting_confirmation' &&
      confirmationPending &&
      (allowedActions.contains('cancel') ||
          allowedActions.contains('confirm-video'));
  bool get canContinue =>
      ['completed', 'failed', 'canceled'].contains(state) && lock == 'released';
  bool get needsPolling =>
      state != 'paused' &&
      (['queued', 'running', 'awaiting_confirmation'].contains(state) ||
          (lock != null && lock != 'released'));
  RoleGenerationProgress get progress => RoleGenerationProgress(
    status: switch (state) {
      'completed' => RoleGenerationStatus.completed,
      'failed' => RoleGenerationStatus.failed,
      'canceled' => RoleGenerationStatus.canceled,
      'paused' => RoleGenerationStatus.paused,
      'queued' ||
      'running' when intent == 'pause' => RoleGenerationStatus.pausing,
      'queued' ||
      'running' when intent == 'cancel' => RoleGenerationStatus.canceling,
      _ => RoleGenerationStatus.running,
    },
    stage: state == 'completed'
        ? 5
        : ((steps.isNotEmpty && steps.first['key'] == 'persona' ? 0 : 1) +
                  steps
                      .takeWhile((step) => step['state'] == 'completed')
                      .length)
              .clamp(0, 4),
  );
  List<({String kind, String title, String body, String? mediaId})>
  get artifacts => [
    for (final step in steps)
      if (step['output'] is Map)
        (
          kind: step['key']?.toString() ?? '',
          title:
              homeObject(step['output'])['title']?.toString() ??
              step['key'].toString(),
          body: homeObject(step['output'])['body']?.toString() ?? '',
          mediaId: homeObject(step['output'])['mediaId']?.toString(),
        ),
  ];
}
