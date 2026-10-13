import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_menu.dart';
import '../../data/media_preferences_repository.dart';
import '../../domain/home_creation.dart';
import '../../domain/session_media_preferences.dart';
import 'generation_config_controls.dart';
import 'role_guide_controls.dart';
import 'role_guide_sheet.dart';

typedef HomeGenerationConfiguration = ({
  HomeConfig? config,
  num? points,
  String description,
});

/// Edits a generation plan or saves server-owned conversation preferences.
class HomeGenerationConfigSheet extends StatefulWidget {
  const HomeGenerationConfigSheet({
    required this.repository,
    required this.sessionId,
    this.saved,
    this.forGeneration = true,
    super.key,
  });
  final MediaPreferencesRepository repository;
  final bool forGeneration;
  final String sessionId;
  final HomeConfig? saved;

  @override
  State<HomeGenerationConfigSheet> createState() =>
      _HomeGenerationConfigSheetState();
}

class _HomeGenerationConfigSheetState extends State<HomeGenerationConfigSheet> {
  final _token = CancelToken();
  CancelToken? _estimateToken;
  Timer? _debounce;
  final _catalogs = <String, List<HomeModel>>{};
  final _configs = <String, HomeConfig?>{};
  final _original = <String, HomeConfig?>{};
  final _customDurations = <String, num>{};
  String _mediaType = 'video';
  num? _points;
  bool _loading = true;
  bool _failed = false;
  bool _estimateFailed = false;
  bool _saving = false;
  bool _saveFailed = false;
  ScrollController? _scrollController;

  List<HomeModel> get _models => _catalogs[_mediaType] ?? const [];
  HomeConfig? get _config => _configs[_mediaType];
  HomeModel? _modelFor(String mediaType) {
    for (final model in _catalogs[mediaType] ?? <HomeModel>[]) {
      if (model.id == _configs[mediaType]?.modelId) return model;
    }
    return null;
  }

  HomeModel? get _model => _modelFor(_mediaType);
  bool _validFor(String mediaType) {
    final config = _configs[mediaType];
    return config != null && _modelFor(mediaType)?.accepts(config) == true;
  }

  bool get _valid => widget.forGeneration
      ? _validFor('video')
      : ((_catalogs['video']?.isEmpty ?? true) || _validFor('video')) &&
            ((_catalogs['image']?.isEmpty ?? true) || _validFor('image')) &&
            _catalogs.values.any((models) => models.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _estimateToken?.cancel();
    _token.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final mediaTypes = widget.forGeneration ? ['video'] : ['video', 'image'];
      final results = await Future.wait<Object>([
        for (final mediaType in mediaTypes)
          widget.repository.models(mediaType: mediaType, cancelToken: _token),
        if (!widget.forGeneration)
          widget.repository.mediaPreferences(
            widget.sessionId,
            cancelToken: _token,
          ),
      ]);
      if (!mounted) return;
      final preferences = widget.forGeneration
          ? null
          : results[2] as SessionMediaPreferences;
      setState(() {
        for (var i = 0; i < mediaTypes.length; i++) {
          _catalogs[mediaTypes[i]] = results[i] as List<HomeModel>;
        }
        _original['video'] = preferences?.video;
        _original['image'] = preferences?.image;
        for (final mediaType in mediaTypes) {
          final models = _catalogs[mediaType]!;
          final saved =
              _original[mediaType] ??
              (mediaType == 'video' ? widget.saved : null);
          _configs[mediaType] =
              saved != null && models.any((model) => model.accepts(saved))
              ? saved
              : models.isEmpty
              ? null
              : models
                    .firstWhere(
                      (model) => model.isDefault,
                      orElse: () => models.first,
                    )
                    .defaultConfig;
          final config = _configs[mediaType];
          if (config != null) {
            _configs[mediaType] = _modelFor(
              mediaType,
            )!.withExplicitDurations(config);
          }
        }
      });
      _estimate();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _change(String name, Object? value) {
    final params = {..._config!.params};
    if (value == null) {
      params.remove(name);
    } else {
      params[name] = value;
    }
    setState(() {
      _configs[_mediaType] = HomeConfig(
        modelId: _config!.modelId,
        params: params,
      );
      _saveFailed = false;
    });
    if (_mediaType == 'video') _estimate();
  }

  void _estimate() {
    if (!widget.forGeneration) return;
    _debounce?.cancel();
    _estimateToken?.cancel();
    setState(() {
      _points = null;
      _estimateFailed = false;
    });
    if (!_validFor('video')) return;
    final token = _estimateToken = CancelToken();
    final config = _configs['video']!;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final points = await widget.repository.estimate(
          config,
          cancelToken: token,
        );
        if (mounted && !token.isCancelled) setState(() => _points = points);
      } catch (_) {
        if (mounted && !token.isCancelled) {
          setState(() => _estimateFailed = true);
        }
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_valid || (widget.forGeneration && _points == null)) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      if (!widget.forGeneration) {
        for (final mediaType in ['video', 'image']) {
          final config = _configs[mediaType];
          if (config == null || config.matches(_original[mediaType])) {
            continue;
          }
          await widget.repository.saveMediaPreference(
            widget.sessionId,
            mediaType,
            config,
            cancelToken: _token,
          );
          _original[mediaType] = config;
        }
      }
      if (mounted) {
        Navigator.of(context).pop<HomeGenerationConfiguration>((
          config: _configs['video'],
          points: _points,
          description: [
            for (final type in ['video', 'image'])
              if (_configs[type] != null)
                '${_modelFor(type)?.name}: ${_configs[type]!.params.values.join(' / ')}',
          ].join('\n'),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    ),
  );

  Widget _parameter(HomeParameter parameter) {
    final value = _config!.params[parameter.name];
    final name = parameter.name.toLowerCase().replaceAll('_', '');
    if (name.contains('duration')) {
      final control = _duration(parameter, value);
      if (control != null) return _section(parameter.label, control);
    }
    if (parameter.options.isNotEmpty &&
        (name.contains('resolution') || name.contains('ratio'))) {
      return _section(
        parameter.label,
        name.contains('ratio')
            ? GenerationRatioGrid(
                key: Key('home-config-${parameter.name}'),
                options: parameter.options,
                value: value,
                keyPrefix: 'home-config-${parameter.name}',
                onSelected: (value) => _change(parameter.name, value),
              )
            : GenerationOptions(
                key: Key('home-config-${parameter.name}'),
                options: parameter.options,
                value: value,
                keyPrefix: 'home-config-${parameter.name}',
                onSelected: (value) => _change(parameter.name, value),
              ),
      );
    }
    final options = parameter.options
        .where(
          (option) =>
              !name.contains('duration') ||
              (option.value != 'auto' && option.value != 'automatic'),
        )
        .toList();
    if (parameter.options.isNotEmpty && options.isEmpty) {
      return const SizedBox.shrink();
    }
    if (options.isNotEmpty) {
      final selected = options.where((option) => option.value == value);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(parameter.label),
        subtitle: Text(selected.isEmpty ? '' : selected.first.label),
        trailing: AppMenuButton(
          key: Key('home-config-${parameter.name}'),
          tooltip: parameter.label,
          icon: const Icon(Icons.expand_more),
          entries: [
            for (final option in options)
              AppMenuItem(
                label: option.label,
                selected: option.value == value,
                onSelected: () => _change(parameter.name, option.value),
              ),
          ],
        ),
      );
    }
    if (parameter.type == 'boolean') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(parameter.label),
        value: value == true,
        onChanged: (value) => _change(parameter.name, value),
      );
    }
    final numeric = parameter.type == 'number' || parameter.type == 'integer';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        key: ValueKey('$_mediaType:${_config!.modelId}:${parameter.name}'),
        initialValue: value?.toString() ?? '',
        decoration: InputDecoration(labelText: parameter.label),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (text) => _change(
          parameter.name,
          numeric
              ? parameter.type == 'integer'
                    ? int.tryParse(text)
                    : num.tryParse(text)
              : text,
        ),
      ),
    );
  }

  Widget? _duration(HomeParameter parameter, Object? value) {
    final values =
        parameter.options
            .map((option) => option.value)
            .whereType<num>()
            .where((value) => value.isFinite)
            .toSet()
            .toList()
          ..sort();
    if (parameter.options.any(
      (option) =>
          option.value is! num &&
          option.value != 'auto' &&
          option.value != 'automatic',
    )) {
      return null;
    }
    final min = values.isNotEmpty ? values.first : parameter.min;
    final max = values.isNotEmpty ? values.last : parameter.max;
    final step = parameter.step ?? 1;
    if (min == null ||
        max == null ||
        !min.isFinite ||
        !max.isFinite ||
        max < min ||
        !step.isFinite ||
        step <= 0) {
      return null;
    }
    final cacheKey = '$_mediaType:${_config!.modelId}:${parameter.name}';
    if (value is num) _customDurations[cacheKey] = value;
    final customValue =
        _customDurations[cacheKey] ??
        (parameter.defaultValue is num ? parameter.defaultValue as num : min);
    return GenerationDurationControl(
      keyPrefix: 'home-config-${parameter.name}',
      value: value is num ? value : null,
      customValue: customValue,
      min: min,
      max: max,
      step: step,
      values: values,
      onChanged: (seconds) {
        if (seconds == null) return;
        _change(
          parameter.name,
          parameter.type == 'integer' ? seconds.toInt() : seconds,
        );
      },
    );
  }

  int _parameterOrder(HomeParameter parameter) {
    final name = parameter.name.toLowerCase();
    if (name.contains('resolution')) return 0;
    if (name.contains('ratio')) return 1;
    if (name.contains('duration')) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parameters = [...?_model?.parameters]
      ..sort((a, b) => _parameterOrder(a).compareTo(_parameterOrder(b)));
    return RoleGuideSheet(
      key: const Key('home-generation-config-sheet'),
      title: l10n.roleModelParameters,
      header: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              l10n.roleModelParameters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if (!widget.forGeneration) ...[
              const SizedBox(height: 20),
              RoleGuideSegments(
                labels: [l10n.roleVideoPreference, l10n.roleImagePreference],
                selected: _mediaType == 'image' ? 1 : 0,
                onSelected: (index) {
                  setState(() => _mediaType = index == 1 ? 'image' : 'video');
                  _scrollController?.jumpTo(0);
                },
              ),
            ],
          ],
        ),
      ),
      builder: (_, controller) {
        _scrollController = controller;
        return AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            key: const Key('home-generation-config-scroll'),
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              if (_loading)
                const LinearProgressIndicator()
              else if (_failed)
                TextButton(
                  onPressed: _load,
                  child: Text('${l10n.roleRequestFailed} · ${l10n.retry}'),
                )
              else if (_models.isEmpty)
                Text(
                  _mediaType == 'video'
                      ? l10n.roleNoVideoModels
                      : l10n.roleNoImageModels,
                )
              else ...[
                Text(
                  l10n.roleModelSelection,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                for (final model in _models) ...[
                  GenerationModelTile(
                    key: Key('home-config-model-${model.id}'),
                    name: model.name,
                    description: model.description,
                    brand: GenerationModelTile.identify(model.name),
                    selected: model.id == _config?.modelId,
                    onSelected: () {
                      if (model.id == _config?.modelId) return;
                      setState(() {
                        _configs[_mediaType] = model.withExplicitDurations(
                          model.defaultConfig,
                        );
                        _saveFailed = false;
                      });
                      if (_mediaType == 'video') _estimate();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                for (final parameter in parameters) _parameter(parameter),
              ],
              if (_saveFailed)
                Text(
                  l10n.roleRequestFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 5),
            ],
          ),
        );
      },
      footer: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.forGeneration &&
                !_loading &&
                !_failed &&
                (_catalogs['video']?.isNotEmpty ?? false)) ...[
              if (_estimateFailed)
                TextButton(
                  onPressed: _saving ? null : _estimate,
                  child: Text('${l10n.roleRequestFailed} · ${l10n.retry}'),
                )
              else
                Text(
                  (widget.forGeneration && _points == null)
                      ? l10n.roleEstimatePending
                      : l10n.chatEstimatedPoints(_points.toString()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 10),
            ],
            RoleGuideAction(
              key: const Key('home-config-confirm'),
              label: _saveFailed ? l10n.retry : l10n.confirm,
              showArrow: false,
              fontSize: 16,
              onPressed:
                  _loading ||
                      _failed ||
                      _saving ||
                      !_valid ||
                      (widget.forGeneration && _points == null)
                  ? null
                  : _save,
            ),
          ],
        ),
      ),
    );
  }
}
