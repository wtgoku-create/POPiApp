import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_menu.dart';
import '../../data/home_creation_repository.dart';
import '../../domain/home_creation.dart';
import 'role_guide_controls.dart';
import 'role_guide_sheet.dart';

typedef HomeGenerationConfiguration = ({HomeConfig config, num points});

/// Uses server model options and pricing before confirming the local selection.
class HomeGenerationConfigSheet extends StatefulWidget {
  const HomeGenerationConfigSheet({
    required this.repository,
    this.saved,
    super.key,
  });
  final HomeCreationRepository repository;
  final HomeConfig? saved;
  @override
  State<HomeGenerationConfigSheet> createState() =>
      _HomeGenerationConfigSheetState();
}

class _HomeGenerationConfigSheetState extends State<HomeGenerationConfigSheet> {
  final _token = CancelToken();
  CancelToken? _estimateToken;
  Timer? _debounce;
  List<HomeModel> _models = const [];
  HomeConfig? _config;
  num? _points;
  bool _loading = true;
  bool _failed = false;
  bool _estimateFailed = false;
  HomeModel? get _model {
    for (final model in _models) {
      if (model.id == _config?.modelId) return model;
    }
    return null;
  }

  bool get _valid => _config != null && _model?.accepts(_config!) == true;
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
      final models = await widget.repository.models(cancelToken: _token);
      if (!mounted) return;
      setState(() {
        _models = models;
        final saved = widget.saved;
        if (saved != null && models.any((model) => model.accepts(saved))) {
          _config = saved;
        } else if (models.isNotEmpty) {
          _config = models
              .firstWhere(
                (model) => model.isDefault,
                orElse: () => models.first,
              )
              .defaultConfig;
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
    setState(
      () => _config = HomeConfig(
        modelId: _config!.modelId,
        params: {..._config!.params, name: value},
      ),
    );
    _estimate();
  }

  void _estimate() {
    _debounce?.cancel();
    _estimateToken?.cancel();
    setState(() {
      _points = null;
      _estimateFailed = false;
    });
    if (!_valid) return;
    final token = _estimateToken = CancelToken();
    final config = _config!;
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

  Widget _parameter(HomeParameter parameter) {
    final value = _config!.params[parameter.name];
    if (parameter.options.isNotEmpty) {
      final selected = parameter.options.where(
        (option) => option.value == value,
      );
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(parameter.label),
        subtitle: Text(selected.isEmpty ? '' : selected.first.label),
        trailing: AppMenuButton(
          key: Key('home-config-${parameter.name}'),
          tooltip: parameter.label,
          icon: const Icon(Icons.expand_more),
          entries: [
            for (final option in parameter.options)
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
        key: ValueKey('${_config!.modelId}:${parameter.name}'),
        initialValue: value?.toString() ?? '',
        decoration: InputDecoration(labelText: parameter.label),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (text) => _change(
          parameter.name,
          numeric
              ? (parameter.type == 'integer'
                    ? int.tryParse(text)
                    : num.tryParse(text))
              : text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RoleGuideSheet(
      key: const Key('home-generation-config-sheet'),
      title: l10n.roleModelParameters,
      builder: (_, controller) => ListView(
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
            Text(l10n.roleNoVideoModels)
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.roleModelSelection),
              subtitle: Text(_model?.name ?? ''),
              trailing: AppMenuButton(
                tooltip: l10n.roleModelSelection,
                key: const Key('home-config-model'),
                icon: const Icon(Icons.expand_more),
                entries: [
                  for (final model in _models)
                    AppMenuItem(
                      label: model.name,
                      selected: model.id == _config?.modelId,
                      onSelected: () {
                        setState(() => _config = model.defaultConfig);
                        _estimate();
                      },
                    ),
                ],
              ),
            ),
            for (final parameter in _model?.parameters ?? <HomeParameter>[])
              _parameter(parameter),
            const SizedBox(height: 20),
            if (_estimateFailed)
              TextButton(
                onPressed: _estimate,
                child: Text('${l10n.roleRequestFailed} · ${l10n.retry}'),
              )
            else
              Text(
                _points == null
                    ? l10n.roleEstimatePending
                    : l10n.chatEstimatedPoints(_points.toString()),
              ),
          ],
        ],
      ),
      footer: RoleGuideAction(
        key: const Key('home-config-confirm'),
        label: l10n.confirm,
        showArrow: false,
        onPressed: !_valid || _points == null
            ? null
            : () => Navigator.of(context).pop<HomeGenerationConfiguration>((
                config: _config!,
                points: _points!,
              )),
      ),
    );
  }
}
