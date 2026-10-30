import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../v2_shared/data/v2_repository.dart';
import '../../../v2_shared/domain/v2_models.dart';
import '../../../v2_shared/presentation/widgets/v2_widgets.dart';

/// Edits all account preferences in one versioned session update.
class V2PreferencesSheet extends StatefulWidget {
  const V2PreferencesSheet({
    required this.repository,
    required this.session,
    super.key,
  });
  final V2Repository repository;
  final V2Session session;
  @override
  State<V2PreferencesSheet> createState() => _V2PreferencesSheetState();
}

class _V2PreferencesSheetState extends State<V2PreferencesSheet> {
  late final _fields = {
    'direction': TextEditingController(text: widget.session.direction),
    for (final key in ['feeling', 'format', 'audience'])
      key: TextEditingController(
        text: widget.session.accountPreferences[key] ?? '',
      ),
  };
  bool _busy = false;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await v2Perform(
      context,
      () => widget.repository.updateSession(
        widget.session.id,
        (s) => s.copyWith(
          direction: _fields['direction']!.text.trim(),
          accountPreferences: {
            ...s.accountPreferences,
            for (final key in ['feeling', 'format', 'audience'])
              key: _fields[key]!.text.trim(),
          },
        ),
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = {
      'direction': l.demoDirection,
      'feeling': l.demoFeeling,
      'format': l.demoFormat,
      'audience': l.demoAudience,
    };
    return V2SheetBody(
      title: l.demoPreferences,
      footer: V2PrimaryButton(label: l.confirm, busy: _busy, onPressed: _save),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          for (final field in _fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: field.value,
                enabled: !_busy,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: labels[field.key]),
              ),
            ),
        ],
      ),
    );
  }
}
