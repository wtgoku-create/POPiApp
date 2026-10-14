import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Compact material inputs; upload and selection state belong to the card.
class ConversationRoleImageSetup extends StatelessWidget {
  const ConversationRoleImageSetup({
    required this.reference,
    required this.styleTitle,
    required this.uploading,
    required this.onUpload,
    required this.onRemove,
    required this.onChooseStyle,
    super.key,
  });

  final Widget? reference;
  final String styleTitle;
  final bool uploading;
  final VoidCallback? onUpload;
  final VoidCallback? onRemove;
  final VoidCallback? onChooseStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 12,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Column(
              children: [
                SizedBox.square(
                  key: const Key('conversation-reference-tile'),
                  dimension: 80,
                  child: reference == null
                      ? OutlinedButton(
                          onPressed: onUpload,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: colors.primary.withValues(
                              alpha: .05,
                            ),
                            side: BorderSide(
                              color: colors.primary.withValues(alpha: .15),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: uploading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Tooltip(
                                  message: l10n.chatReferenceImage,
                                  child: const Icon(Icons.add, size: 24),
                                ),
                        )
                      : Stack(
                          children: [
                            Positioned.fill(child: reference!),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                tooltip: l10n.removeImage,
                                onPressed: onRemove,
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colors.surface,
                                ),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.chatReferenceImage,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.chatImageStyle, style: labelStyle),
                const SizedBox(height: 6),
                OutlinedButton(
                  key: const Key('conversation-role-style-select'),
                  onPressed: onChooseStyle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    side: BorderSide(color: colors.outlineVariant),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          styleTitle.isEmpty
                              ? l10n.chatUnrestrictedStyle
                              : styleTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
