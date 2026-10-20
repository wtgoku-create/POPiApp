import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Shared cost notice displayed before authorizing media generation.
class GenerationCreditNotice extends StatelessWidget {
  const GenerationCreditNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notice = l10n.generationCreditNotice;
    final emphasis = l10n.generationCreditNoticeNonRefundable;
    final start = notice.indexOf(emphasis);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text.rich(
        TextSpan(
          children: start < 0
              ? [TextSpan(text: notice)]
              : [
                  TextSpan(text: notice.substring(0, start)),
                  TextSpan(
                    text: emphasis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: notice.substring(start + emphasis.length)),
                ],
        ),
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
