import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/user_provider.dart';

/// Edits a bounded set of profile fields, retaining the command ID on retry.
class IpAccountEditSheet extends ConsumerStatefulWidget {
  const IpAccountEditSheet({
    required this.title,
    required this.fields,
    required this.values,
    required this.onSave,
    super.key,
  });
  final String title;
  final Map<String, String> fields;
  final Map<String, String> values;
  final Future<void> Function(Map<String, String>, String) onSave;

  @override
  ConsumerState<IpAccountEditSheet> createState() => _IpAccountEditSheetState();
}

class _IpAccountEditSheetState extends ConsumerState<IpAccountEditSheet> {
  late final String? _ownerId;
  late final _controllers = {
    for (final key in widget.fields.keys)
      key: TextEditingController(text: widget.values[key] ?? ''),
  };
  bool _saving = false;
  bool _failed = false;
  Map<String, String>? _submitted;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _ownerId = ref.read(userProvider)?.id;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || ref.read(userProvider)?.id != _ownerId) return;
    final values = {
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    if (values.values.any((value) => value.isEmpty)) return;
    if (!mapEquals(values, _submitted)) {
      _submitted = values;
      _requestId = const Uuid().v4();
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave(values, _requestId!);
      if (mounted && ref.read(userProvider)?.id == _ownerId) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, id) {
      if (id != _ownerId && mounted) Navigator.of(context).pop(false);
    });
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                for (final entry in widget.fields.entries) ...[
                  TextField(
                    key: Key('ip-account-edit-${entry.key}'),
                    controller: _controllers[entry.key],
                    enabled: !_saving,
                    minLines: entry.key == 'title' ? 1 : 2,
                    maxLines: entry.key == 'title' ? 1 : 6,
                    maxLength: entry.key == 'title' ? 200 : 4000,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: entry.value,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.networkRequestFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const Key('ip-account-edit-save'),
                        onPressed:
                            _saving ||
                                _controllers.values.any(
                                  (c) => c.text.trim().isEmpty,
                                )
                            ? null
                            : _save,
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.ipAccountSave),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
