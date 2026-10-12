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
}

class HomeModel {
  HomeModel.fromJson(Map<String, Object?> json)
    : id = homeId(json['id']),
      name = json['name']?.toString() ?? '',
      available = json['available'] == true && json['mediaType'] == 'video',
      isDefault = json['isDefault'] == true,
      parameters = homeObjects(json['parameters']).map(_homeParameter).toList();
  final String id;
  final String name;
  final bool available;
  final bool isDefault;
  final List<HomeParameter> parameters;
  bool get supportsHomeDuration => parameters.any(
    (parameter) =>
        parameter.isDuration &&
        parameter.options.any((option) => _homeDuration(option.value)),
  );

  static bool _homeDuration(Object value) => RegExp(
    r'^(15|30)(s|秒|seconds?)?$',
    caseSensitive: false,
  ).hasMatch(value.toString().replaceAll(RegExp(r'\s'), ''));

  static HomeParameter _homeParameter(Map<String, Object?> json) {
    final parameter = HomeParameter.fromJson(json);
    if (!parameter.isDuration) return parameter;
    final options = parameter.options
        .where((option) => _homeDuration(option.value))
        .toList();
    if (options.isEmpty) return parameter;
    return HomeParameter.fromJson({
      ...json,
      'options': [
        for (final option in options)
          {'label': option.label, 'value': option.value},
      ],
      'default': options.any((option) => option.value == parameter.defaultValue)
          ? parameter.defaultValue
          : options.first.value,
    });
  }

  HomeConfig get defaultConfig => HomeConfig(
    modelId: id,
    params: {
      for (final parameter in parameters)
        if (parameter.defaultValue != null)
          parameter.name: parameter.defaultValue,
    },
  );
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
      options = _options(json['options']);
  final String name;
  final String label;
  final String type;
  final bool required;
  final Object? defaultValue;
  final List<({String label, Object value})> options;
  bool get isDuration =>
      name.toLowerCase().contains('duration') ||
      label.contains('时长') ||
      label.contains('時長');

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
      'number' => value is num && value.isFinite,
      'integer' => value is int,
      _ => value is String,
    };
  }
}

class HomeTask {
  HomeTask.fromJson(Map<String, Object?> json)
    : id = homeId(json['id'] ?? json['taskId']),
      state = homeId(json['state'] ?? json['initialState']),
      revision = (json['revision'] ?? json['stateVersion'] ?? 0) as int,
      lock = json['lock']?.toString(),
      allowedActions = (json['allowedActions'] as List? ?? const [])
          .cast<String>(),
      steps = homeObjects(json['steps'] ?? json['stages']);
  final String id;
  final String state;
  final int revision;
  final String? lock;
  final List<String> allowedActions;
  final List<Map<String, Object?>> steps;
  bool get canConfirmVideo => state == 'awaiting_confirmation';
  bool get needsPolling =>
      state != 'paused' &&
      (['queued', 'running', 'awaiting_confirmation'].contains(state) ||
          (lock != null && lock != 'released'));
  RoleGenerationProgress get progress => RoleGenerationProgress(
    status: switch (state) {
      'completed' => RoleGenerationStatus.completed,
      'failed' => RoleGenerationStatus.failed,
      'canceled' => RoleGenerationStatus.canceled,
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
  List<({String title, String body, String? mediaId})> get artifacts => [
    for (final step in steps)
      if (step['output'] is Map)
        (
          title:
              homeObject(step['output'])['title']?.toString() ??
              step['key'].toString(),
          body: homeObject(step['output'])['body']?.toString() ?? '',
          mediaId: homeObject(step['output'])['mediaId']?.toString(),
        ),
  ];
}
