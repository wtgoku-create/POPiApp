import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_skeleton.dart';

/// Placeholder rows matching the account avatar, title, status, and description.
class IpAccountsSkeleton extends StatelessWidget {
  const IpAccountsSkeleton({required this.padding, super.key});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSkeleton(
      label: AppLocalizations.of(context)!.loadingIpAccounts,
      child: ListView.separated(
        padding: padding,
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => Container(
          key: ValueKey('ip-account-skeleton-$index'),
          height: 90,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.brightness == Brightness.light
                ? colors.surface
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Row(
            children: [
              const AppSkeletonBox(width: 50, height: 50, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: index.isEven ? .85 : .65,
                            child: const AppSkeletonBox(height: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const AppSkeletonBox(width: 42, height: 18, radius: 9),
                      ],
                    ),
                    const SizedBox(height: 9),
                    const FractionallySizedBox(
                      widthFactor: .8,
                      child: AppSkeletonBox(height: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const SizedBox.square(
                dimension: 20,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AppSkeletonBox(width: 8, height: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
