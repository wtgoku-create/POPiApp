import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Shared cost notice displayed before authorizing media generation.
class GenerationCreditNotice extends StatelessWidget {
  const GenerationCreditNotice({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      AppLocalizations.of(context)!.generationCreditNotice,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
