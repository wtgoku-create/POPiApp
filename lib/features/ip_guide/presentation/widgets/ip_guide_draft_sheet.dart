import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_sheet.dart';
import 'ip_guide_controls.dart';

/// Resolves the single saved plan before entering the creation steps.
class IpGuideDraftSheet {
  const IpGuideDraftSheet._();

  static Future<bool?> show(BuildContext context) => AppSheet.show<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
    ),
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.ipDraftTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.ipDraftDetected,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                Text(
                  l10n.ipDraftDescription,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                IpGuideNextButton(
                  key: const Key('ip-draft-restart'),
                  label: l10n.ipDraftRestart,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 10),
                TextButton(
                  key: const Key('ip-draft-resume'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: AppColors.brand.withValues(alpha: .05),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shape: const StadiumBorder(),
                    textStyle: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(fontSize: 18),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.ipDraftResume),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
