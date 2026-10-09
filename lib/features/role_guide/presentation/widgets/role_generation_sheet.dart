import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../domain/role_guide_draft.dart';
import 'role_guide_controls.dart';

/// Edits a private copy and returns it only when the user confirms.
class RoleGenerationSheet extends StatefulWidget {
  const RoleGenerationSheet({this.initialSettings, super.key});
  final RoleGenerationSettings? initialSettings;

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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final resolution = _image
        ? _settings.imageResolution
        : _settings.videoResolution;
    final ratio = _image ? _settings.imageRatio : _settings.videoRatio;
    final dimensions = _settings.dimensions(image: _image);

    return DraggableScrollableSheet(
      initialChildSize: AppSheet.relativeExtent(.875),
      minChildSize: AppSheet.relativeExtent(.5),
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) => Material(
        key: const Key('role-generation-sheet'),
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Text(
                l10n.roleModelParameters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RoleGuideSegments(
                labels: [l10n.roleVideoPreference, l10n.roleImagePreference],
                selected: _image ? 1 : 0,
                onSelected: (i) => setState(() => _image = i == 1),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                key: const Key('role-generation-scroll'),
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (!_image) ...[
                    _label(l10n.roleModelSelection),
                    const SizedBox(height: 10),
                    for (final model in GenerationModel.values) ...[
                      _model(model, l10n),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 14),
                  ],
                  _label(l10n.roleResolution),
                  const SizedBox(height: 5),
                  _options(
                    values: const [720, 1080],
                    selected: resolution,
                    label: (value) => '${value}P',
                    keyPrefix: 'role-resolution',
                    onSelected: (value) => setState(() {
                      _settings = _image
                          ? _settings.copyWith(imageResolution: value)
                          : _settings.copyWith(videoResolution: value);
                    }),
                  ),
                  const SizedBox(height: 10),
                  _label(l10n.roleRatio),
                  const SizedBox(height: 5),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 30) / 4;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final value in GenerationRatio.values)
                            SizedBox(
                              width: width,
                              child: _ratio(value, ratio == value),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  _label(l10n.roleDimensions),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(child: _dimension('W', dimensions.width)),
                      Image.asset(
                        'assets/images/role_guide_dimensions_link.png',
                        width: 18,
                        height: 18,
                      ),
                      Expanded(child: _dimension('H', dimensions.height)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _label(l10n.roleQuantity),
                  const SizedBox(height: 5),
                  _options(
                    values: const [1, 2, 3, 4],
                    selected: _settings.quantity,
                    label: (value) => '$value',
                    keyPrefix: 'role-quantity',
                    onSelected: (value) => setState(
                      () => _settings = _settings.copyWith(quantity: value),
                    ),
                  ),
                  const SizedBox(height: 25),
                  RoleGuideAction(
                    key: const Key('role-generation-confirm'),
                    label: l10n.confirm,
                    showArrow: false,
                    onPressed: () => Navigator.of(context).pop(_settings),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _model(GenerationModel model, AppLocalizations l10n) {
    final selected = _settings.model == model;
    final colors = Theme.of(context).colorScheme;
    final description = switch (model) {
      GenerationModel.sora => l10n.roleModelSoraDescription,
      GenerationModel.veo => l10n.roleModelVeoDescription,
      GenerationModel.jimeng => l10n.roleModelJimengDescription,
      GenerationModel.kling => l10n.roleModelKlingDescription,
      GenerationModel.vidu => l10n.roleModelViduDescription,
    };
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? roleGuideTint(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('role-model-${model.name}'),
          onTap: () =>
              setState(() => _settings = _settings.copyWith(model: model)),
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 65),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/role_guide_model_${model.index + 1}.png',
                    width: 26,
                    height: 26,
                    color: selected ? AppColors.brand : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? AppColors.brand
                                      : colors.onSurface,
                                ),
                              ),
                            ),
                            if (model == GenerationModel.veo)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: .2),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  l10n.roleModelDiscount,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: selected
                                ? AppColors.brand
                                : colors.onSurfaceVariant.withValues(
                                    alpha: .65,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _options({
    required List<int> values,
    required int selected,
    required String Function(int) label,
    required String keyPrefix,
    required ValueChanged<int> onSelected,
  }) => Row(
    children: [
      for (final value in values)
        Expanded(
          child: Semantics(
            selected: value == selected,
            child: TextButton(
              key: Key('$keyPrefix-$value'),
              onPressed: () => onSelected(value),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.standard,
                minimumSize: const Size(0, 38),
                backgroundColor: value == selected
                    ? roleGuideTint(context)
                    : Colors.transparent,
                foregroundColor: value == selected
                    ? AppColors.brand
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                shape: const StadiumBorder(),
              ),
              child: Text(label(value)),
            ),
          ),
        ),
    ],
  );

  Widget _ratio(GenerationRatio ratio, bool selected) {
    final color = selected
        ? AppColors.brand
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final maxSide = math.max(ratio.width, ratio.height);
    return Semantics(
      selected: selected,
      child: TextButton(
        key: Key('role-ratio-${ratio.name}'),
        onPressed: () => setState(() {
          _settings = _image
              ? _settings.copyWith(imageRatio: ratio)
              : _settings.copyWith(videoRatio: ratio);
        }),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.standard,
          backgroundColor: selected
              ? roleGuideTint(context)
              : Colors.transparent,
          foregroundColor: color,
          minimumSize: const Size(0, 92),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 32,
              child: Center(
                child: Container(
                  width: 30 * ratio.width / maxSide,
                  height: 30 * ratio.height / maxSide,
                  decoration: BoxDecoration(
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ratio.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimension(String axis, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      '$axis $value',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14),
    ),
  );
}
