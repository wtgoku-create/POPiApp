import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';

/// Requires the same refund acknowledgement as the web book-card exchange.
class BookCardConfirmation extends StatefulWidget {
  const BookCardConfirmation({super.key});

  @override
  State<BookCardConfirmation> createState() => _BookCardConfirmationState();
}

class _BookCardConfirmationState extends State<BookCardConfirmation> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.activityFinalConfirmation,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Text(l10n.activityRefundNotice, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            l10n.activityConfirmationPhrase,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('activity-refund-acknowledgement'),
            controller: _text,
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 50),
                  ),
                  child: Text(l10n.cancel, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const Key('activity-final-confirm'),
                  onPressed:
                      _text.text.trim() == l10n.activityConfirmationPhrase
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 50),
                  ),
                  child: Text(l10n.confirm, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
