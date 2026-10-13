import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/role_guide_draft.dart';
import 'generation_config_controls.dart';
import 'role_guide_controls.dart';
import 'role_guide_sheet.dart';

/// Edits a private copy and returns it only when the user confirms.
class RoleGenerationSheet extends StatefulWidget {
  const RoleGenerationSheet({
    this.initialSettings,
    this.videoOnly = false,
    super.key,
  });
  final RoleGenerationSettings? initialSettings;
  final bool videoOnly;

  @override
  State<RoleGenerationSheet> createState() => _RoleGenerationSheetState();
}

class _RoleGenerationSheetState extends State<RoleGenerationSheet> {
  late RoleGenerationSettings _settings;
  bool _image = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings ?? const RoleGenerationSettings();
    if (_settings.duration == null) {
      _settings = _settings.copyWith(duration: _settings.customDuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RoleGuideSheet(
      key: const Key('role-generation-sheet'),
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
            if (!widget.videoOnly) ...[
              const SizedBox(height: 20),
              RoleGuideSegments(
                labels: [l10n.roleVideoPreference, l10n.roleImagePreference],
                selected: _image ? 1 : 0,
                onSelected: (i) => setState(() => _image = i == 1),
              ),
            ],
          ],
        ),
      ),
      builder: (_, controller) => ListView(
        key: const Key('role-generation-scroll'),
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (!_image) ...[
            _label(l10n.roleModelSelection),
            const SizedBox(height: 10),
            for (final model in GenerationModel.values) ...[
              GenerationModelTile(
                key: Key('role-model-${model.name}'),
                name: model.label,
                brand: model,
                selected: _settings.model == model,
                discount: model == GenerationModel.veo
                    ? l10n.roleModelDiscount
                    : null,
                onSelected: () => setState(
                  () => _settings = _settings.copyWith(model: model),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
          ],
          _label(l10n.roleResolution),
          const SizedBox(height: 5),
          GenerationOptions(
            options: const [
              (label: '720P', value: 720),
              (label: '1080P', value: 1080),
            ],
            value: _image
                ? _settings.imageResolution
                : _settings.videoResolution,
            keyPrefix: 'role-resolution',
            onSelected: (value) => setState(
              () => _settings = _image
                  ? _settings.copyWith(imageResolution: value as int)
                  : _settings.copyWith(videoResolution: value as int),
            ),
          ),
          const SizedBox(height: 10),
          _label(l10n.roleRatio),
          const SizedBox(height: 5),
          GenerationRatioGrid(
            options: [
              for (final ratio in GenerationRatio.values)
                (label: ratio.label, value: ratio.label),
            ],
            value: (_image ? _settings.imageRatio : _settings.videoRatio).label,
            keyPrefix: 'role-ratio',
            optionKey: (value) => GenerationRatio.values
                .firstWhere((ratio) => ratio.label == value)
                .name,
            onSelected: (value) => setState(() {
              final ratio = GenerationRatio.values.firstWhere(
                (ratio) => ratio.label == value,
              );
              _settings = _image
                  ? _settings.copyWith(imageRatio: ratio)
                  : _settings.copyWith(videoRatio: ratio);
            }),
          ),
          if (!_image) ...[
            const SizedBox(height: 15),
            _label(l10n.roleDuration),
            const SizedBox(height: 5),
            GenerationDurationControl(
              keyPrefix: 'role-duration',
              value: _settings.duration,
              customValue: _settings.customDuration,
              min: 1,
              max: 180,
              onChanged: (value) => setState(
                () => _settings = _settings.copyWith(
                  duration: value?.toInt(),
                  automaticDuration: value == null,
                ),
              ),
            ),
          ],
          const SizedBox(height: 5),
        ],
      ),
      footer: RoleGuideAction(
        key: const Key('role-generation-confirm'),
        label: l10n.confirm,
        showArrow: false,
        fontSize: 16,
        onPressed: () => Navigator.of(context).pop(_settings),
      ),
    );
  }

  Widget _label(String label) => Text(
    label,
    style: TextStyle(
      fontSize: 16,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
