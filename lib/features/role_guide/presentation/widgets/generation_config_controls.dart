import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/role_guide_draft.dart';
import 'role_guide_controls.dart';

/// The model list and parameter controls shared by live and preview generation.
class GenerationModelTile extends StatelessWidget {
  const GenerationModelTile({
    required this.name,
    required this.selected,
    required this.onSelected,
    this.description,
    this.brand,
    this.discount,
    super.key,
  });

  final String name;
  final String? description;
  final GenerationModel? brand;
  final String? discount;
  final bool selected;
  final VoidCallback onSelected;

  static GenerationModel? identify(String name) {
    final normalized = name.toLowerCase();
    for (final model in GenerationModel.values) {
      if (normalized.contains(model.name)) return model;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final detail =
        description ??
        switch (brand) {
          GenerationModel.sora => l10n.roleModelSoraDescription,
          GenerationModel.veo => l10n.roleModelVeoDescription,
          GenerationModel.jimeng => l10n.roleModelJimengDescription,
          GenerationModel.kling => l10n.roleModelKlingDescription,
          GenerationModel.vidu => l10n.roleModelViduDescription,
          null => null,
        };
    final foreground = selected ? AppColors.brand : colors.onSurface;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? roleGuideTint(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 65),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (brand case final model?)
                    Image.asset(
                      'assets/images/role_guide_model_${model.index + 1}.png',
                      width: 26,
                      height: 26,
                      color: selected
                          ? AppColors.brand
                          : colors.onSurfaceVariant,
                    )
                  else
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 26,
                      color: foreground,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                        if (detail != null && detail.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            detail,
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
                      ],
                    ),
                  ),
                  if (discount != null) ...[
                    const SizedBox(width: 8),
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
                        discount!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GenerationOptions extends StatelessWidget {
  const GenerationOptions({
    required this.options,
    required this.value,
    required this.onSelected,
    required this.keyPrefix,
    super.key,
  });
  final List<({String label, Object value})> options;
  final Object? value;
  final ValueChanged<Object> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = math.max(1, (constraints.maxWidth / 120).floor());
      final columns = math.min(count, options.length);
      return Wrap(
        children: [
          for (final option in options)
            SizedBox(
              width: constraints.maxWidth / math.max(1, columns),
              child: Semantics(
                selected: option.value == value,
                child: TextButton(
                  key: Key('$keyPrefix-${option.value}'),
                  onPressed: () => onSelected(option.value),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: option.value == value
                        ? roleGuideTint(context)
                        : Colors.transparent,
                    foregroundColor: option.value == value
                        ? AppColors.brand
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  child: Text(option.label, textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class GenerationRatioGrid extends StatelessWidget {
  const GenerationRatioGrid({
    required this.options,
    required this.value,
    required this.onSelected,
    required this.keyPrefix,
    this.optionKey,
    super.key,
  });
  final List<({String label, Object value})> options;
  final Object? value;
  final ValueChanged<Object> onSelected;
  final String keyPrefix;
  final String Function(Object)? optionKey;

  static ({double width, double height})? dimensions(Object value) {
    final parts = value.toString().split(':');
    if (parts.length != 2) return null;
    final width = double.tryParse(parts[0]);
    final height = double.tryParse(parts[1]);
    if (width == null ||
        height == null ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return (width: width, height: height);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = MediaQuery.textScalerOf(context).scale(14) > 21 ? 3 : 4;
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final option in options)
            SizedBox(width: width, child: _tile(context, option)),
        ],
      );
    },
  );

  Widget _tile(BuildContext context, ({String label, Object value}) option) {
    final selected = option.value == value;
    final color = selected
        ? AppColors.brand
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final ratio = dimensions(option.value);
    final maxSide = ratio == null ? 1.0 : math.max(ratio.width, ratio.height);
    return Semantics(
      selected: selected,
      child: TextButton(
        key: Key('$keyPrefix-${optionKey?.call(option.value) ?? option.value}'),
        onPressed: () => onSelected(option.value),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 92),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 16),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: selected
              ? roleGuideTint(context)
              : Colors.transparent,
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 32,
              child: Center(
                child: ratio == null
                    ? Icon(Icons.aspect_ratio, color: color, size: 30)
                    : Container(
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
              option.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps the slider to allowed numeric values without inventing API options.
class GenerationDurationControl extends StatelessWidget {
  const GenerationDurationControl({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.customValue,
    this.step = 1,
    this.values = const [],
    this.keyPrefix = 'generation-duration',
    super.key,
  });
  final num? value;
  final num customValue;
  final num min;
  final num max;
  final num step;
  final List<num> values;
  final ValueChanged<num?> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final divisions = values.isNotEmpty
        ? values.length - 1
        : ((max - min) / step).floor();
    final numeric = value ?? customValue;
    final selectedIndex = values.indexOf(numeric);
    final position = values.isNotEmpty
        ? math.max(0, selectedIndex).toDouble()
        : ((numeric - min) / step)
              .round()
              .clamp(0, math.max(0, divisions))
              .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.roleDurationSeconds(numeric.toString()),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          children: [
            Text(
              l10n.roleDurationSeconds(min.toString()),
              style: const TextStyle(fontSize: 14),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: AppColors.brand,
                  inactiveTrackColor: roleGuideTint(context),
                  thumbColor: AppColors.brand,
                ),
                child: Slider(
                  key: Key('$keyPrefix-slider'),
                  min: 0,
                  max: math.max(1, divisions).toDouble(),
                  divisions: divisions > 0 ? divisions : null,
                  value: position,
                  onChanged: divisions <= 0
                      ? null
                      : (position) => onChanged(
                          values.isNotEmpty
                              ? values[position.round()]
                              : min + position.round() * step,
                        ),
                ),
              ),
            ),
            Text(
              l10n.roleDurationSeconds(max.toString()),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}
