import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_expanded_text_field.dart';
import '../../../../shared/type/account_input_type.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

/// Shared next action with the pill shape and exported chevron from the design.
class IpGuideNextButton extends StatelessWidget {
  const IpGuideNextButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          if (loading)
            const SizedBox.square(
              dimension: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            const AppSvgIcon.asset(
              'home_welcome_chevron',
              size: 13,
              color: Colors.white,
            ),
        ],
      ),
    ),
  );
}

/// Account guide input backed by the shared expanded editor.
class IpGuideTextField extends AppExpandedTextField {
  const IpGuideTextField({
    required super.controller,
    required super.hint,
    super.limit = AccountInputLimits.customCharacters,
    super.maxBytes,
    super.nickname,
    super.readOnly,
    super.editInSheet,
    super.key,
  }) : super(
         editorInputKey: const Key('ip-guide-expanded-input'),
         editorConfirmKey: const Key('ip-guide-editor-confirm'),
       );
}

class IpGuideSelectionBadge extends StatelessWidget {
  const IpGuideSelectionBadge({
    required this.order,
    this.single = false,
    super.key,
  });

  final int order;
  final bool single;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: order > 0
          ? AppColors.brand
          : Theme.of(context).colorScheme.surface,
      border: order > 0
          ? null
          : Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 4,
            ),
    ),
    child: order == 0
        ? null
        : single
        ? const Icon(Icons.check, size: 14, color: Colors.white)
        : Text(
            '$order',
            style: const TextStyle(
              fontSize: 14,
              height: 1,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
  );
}

/// Wraps summary chips so translated labels and large text remain inside the panel.
class IpGuideSelectionSummary extends StatelessWidget {
  const IpGuideSelectionSummary({required this.labels, super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < labels.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  i == 0
                      ? l10n.ipPrimarySelection(labels[i])
                      : l10n.ipSecondarySelection(labels[i]),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    color: colors.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
