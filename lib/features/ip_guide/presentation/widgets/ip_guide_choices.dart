import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_network_image.dart';
import '../../../../app/theme.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/ip_guide_draft.dart';
import '../../../ip_accounts/domain/account_preferences.dart';
import 'ip_guide_controls.dart';

/// Ordered choices; rows grow together when translated text needs more room.
class IpGuideChoiceGrid<T> extends StatelessWidget {
  const IpGuideChoiceGrid({
    required this.values,
    required this.selection,
    required this.label,
    required this.onSelected,
    required this.keyPrefix,
    required this.valueKey,
    this.icon,
    this.imageUrl,
    this.description,
    this.showAvatar = true,
    super.key,
  });

  final List<T> values;
  final IpGuideSelection<T> selection;
  final String Function(T) label;
  final String? Function(T)? icon;
  final String? Function(T)? imageUrl;
  final String Function(T) valueKey;
  final String Function(T)? description;
  final ValueChanged<T> onSelected;
  final String keyPrefix;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(18) > 22;
      final columns = description == null
          ? (compact ? 2 : 3)
          : (compact ? 1 : 2);
      return Column(
        children: [
          for (var row = 0; row < (values.length / columns).ceil(); row++) ...[
            if (row > 0) const SizedBox(height: 15),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 15),
                    Expanded(
                      child: row * columns + column >= values.length
                          ? const SizedBox()
                          : _choice(context, values[row * columns + column]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _choice(BuildContext context, T value) {
    final colors = Theme.of(context).colorScheme;
    final order = selection.values.indexOf(value) + 1;
    final feeling = description != null;
    final textColor = !feeling && order > 0 ? colors.primary : colors.onSurface;
    return Semantics(
      selected: order > 0,
      button: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: feeling ? 125 : 110),
        child: Material(
          color: order > 0
              ? colors.primary.withValues(alpha: .05)
              : colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: Key('$keyPrefix-${valueKey(value)}'),
            onTap: () => onSelected(value),
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(feeling ? 20 : 15),
                  child: feeling
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Row(
                                children: [
                                  if (showAvatar)
                                    ClipOval(
                                      child: Image.asset(
                                        'assets/images/ip_guide_feeling_avatar.png',
                                        width: 30,
                                        height: 30,
                                        fit: BoxFit.cover,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                  if (showAvatar) const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      label(value),
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              description!(value),
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _image(value),
                              const SizedBox(height: 10),
                              Text(
                                label(value),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IpGuideSelectionBadge(order: order),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(T value) {
    final asset = icon?.call(value);
    final fallback = asset == null
        ? const Icon(Icons.auto_awesome_outlined, size: 44)
        : AppSvgIcon.asset(asset, size: 44);
    final url = imageUrl?.call(value);
    if (url == null || url.isEmpty) return fallback;
    return AppNetworkImage(
      url,
      width: 44,
      height: 44,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class IpGuidePresentationChoices extends StatelessWidget {
  const IpGuidePresentationChoices({
    required this.options,
    required this.selection,
    required this.onSelected,
    super.key,
  });

  final List<AccountPreferenceOption> options;
  final IpGuideSelection<String> selection;
  final ValueChanged<String> onSelected;

  static const _images = {
    'AI 真人': 'assets/images/ip_guide_ai_real.png',
    'AI真人': 'assets/images/ip_guide_ai_real.png',
    '2D 动画': 'assets/images/ip_guide_2d.png',
    '2D动漫': 'assets/images/ip_guide_2d.png',
    '3D 动漫': 'assets/images/ip_guide_3d.png',
    '3D动漫': 'assets/images/ip_guide_3d.png',
    '真人实拍': 'assets/images/ip_guide_live.png',
    '萌宠': 'assets/images/ip_guide_pets.png',
    '黏土定格': 'assets/images/ip_guide_clay.png',
    '定格动画': 'assets/images/ip_guide_clay.png',
    '国风水墨': 'assets/images/ip_guide_ink.png',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 300 &&
              MediaQuery.textScalerOf(context).scale(18) > 22
          ? 1
          : 2;
      return Column(
        children: [
          for (var row = 0; row < (options.length / columns).ceil(); row++) ...[
            if (row > 0) const SizedBox(height: 15),
            Row(
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 15),
                  Expanded(
                    child: row * columns + column >= options.length
                        ? const SizedBox()
                        : _tile(context, options[row * columns + column]),
                  ),
                ],
              ],
            ),
          ],
        ],
      );
    },
  );

  Widget _tile(BuildContext context, AccountPreferenceOption value) {
    final order = selection.values.indexOf(value.name) + 1;
    return Semantics(
      selected: order > 0,
      button: true,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('ip-presentation-${value.name}'),
          onTap: () => onSelected(value.name),
          child: SizedBox(
            height: 125,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(context, value),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 33),
                        color: Colors.white.withValues(alpha: .65),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          value.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IpGuideSelectionBadge(order: order),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(BuildContext context, AccountPreferenceOption option) {
    final asset = _images[option.name];
    final fallback = asset == null
        ? ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.palette_outlined, size: 44)),
          )
        : Image.asset(asset, fit: BoxFit.cover, excludeFromSemantics: true);
    final url = option.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return AppNetworkImage(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
