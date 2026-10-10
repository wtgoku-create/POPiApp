import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

/// The shared reward artwork and copy from the mobile redemption design.
class RedemptionBanner extends StatelessWidget {
  const RedemptionBanner({
    required this.title,
    required this.description,
    this.points,
    super.key,
  });

  final String title;
  final String description;
  final int? points;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: ColoredBox(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white.withValues(alpha: .5)
                : colors.surfaceContainerLow,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 168),
              child: Stack(
                children: [
                  Positioned(
                    right: compact ? 0 : 8,
                    bottom: 0,
                    child: SizedBox(
                      width: compact ? 100 : 180,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          const Positioned(
                            bottom: 12,
                            child: AppSvgIcon.asset(
                              'redemption_gift_bubble',
                              size: 140,
                            ),
                          ),
                          Image.asset(
                            'assets/images/redemption_gift_character.png',
                            width: compact ? 90 : 140,
                            height: 145,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      compact ? 110 : 155,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (points != null) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 7,
                            children: [
                              Text(
                                '+$points',
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                AppLocalizations.of(context)!.redemptionPoints,
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          description,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
