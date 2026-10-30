import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../v2_shared/data/v2_repository.dart';
import '../../../v2_shared/domain/v2_models.dart';
import '../../../v2_shared/presentation/widgets/v2_widgets.dart';

/// Keeps selections through request failures and sends the question revision.
class V2QuestionCard extends StatefulWidget {
  const V2QuestionCard({
    required this.question,
    required this.repository,
    required this.sessionId,
    super.key,
  });
  final V2Question question;
  final V2Repository repository;
  final String sessionId;
  @override
  State<V2QuestionCard> createState() => _V2QuestionCardState();
}

class _V2QuestionCardState extends State<V2QuestionCard> {
  final Map<String, Set<String>> _selected = {};
  final Map<String, String> _custom = {};
  final Map<String, TextEditingController> _inputs = {};
  bool _busy = false;
  bool _accepted = false;
  @override
  void initState() {
    super.initState();
    _restoreAnswers();
  }

  void _restoreAnswers() {
    for (final field in widget.question.questions) {
      final value = widget.question.answer[field.id];
      final values = value is List
          ? value.cast<String>()
          : value is String
          ? [value]
          : <String>[];
      final labels = field.options.map((o) => o.label).toSet();
      _selected[field.id] = values.where(labels.contains).toSet();
      _custom[field.id] = values.where((v) => !labels.contains(v)).join(' / ');
      (_inputs[field.id] ??= TextEditingController()).text = _custom[field.id]!;
    }
  }

  @override
  void didUpdateWidget(V2QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.question.isPending &&
        oldWidget.question.status != widget.question.status) {
      _restoreAnswers();
    }
  }

  @override
  void dispose() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _enabled => widget.question.isPending && !_busy && !_accepted;
  Map<String, Object?> get _answer => {
    for (final field in widget.question.questions)
      field.id: field.multiSelect
          ? [
              ...?_selected[field.id],
              if (_custom[field.id]?.trim().isNotEmpty == true)
                _custom[field.id]!.trim(),
            ]
          : _custom[field.id]?.trim().isNotEmpty == true
          ? _custom[field.id]!.trim()
          : _selected[field.id]?.firstOrNull ?? '',
  };
  Future<void> _submit(String action) async {
    setState(() => _busy = true);
    final ok = await v2Perform(
      context,
      () => widget.repository.respondQuestion(
        widget.sessionId,
        widget.question,
        action,
        _answer,
      ),
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _accepted = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.question.title.isNotEmpty) Text(widget.question.title),
          for (final field in widget.question.questions) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                field.question,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final option in field.options)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                subtitle: option.description.isEmpty
                    ? null
                    : Text(option.description),
                value: _selected[field.id]?.contains(option.label) ?? false,
                onChanged: !_enabled
                    ? null
                    : (checked) => setState(() {
                        final values = _selected.putIfAbsent(
                          field.id,
                          () => {},
                        );
                        if (!field.multiSelect) values.clear();
                        if (checked == true) {
                          values.add(option.label);
                        } else {
                          values.remove(option.label);
                        }
                        if (!field.multiSelect) {
                          _custom.remove(field.id);
                          _inputs[field.id]?.clear();
                        }
                      }),
              ),
            TextFormField(
              key: ValueKey(
                '${widget.question.id}:${widget.question.revision}:${field.id}',
              ),
              enabled: _enabled,
              controller: _inputs[field.id],
              decoration: InputDecoration(hintText: l.v2CustomAnswer),
              onChanged: (value) => setState(() {
                _custom[field.id] = value;
                if (!field.multiSelect && value.trim().isNotEmpty) {
                  _selected[field.id]?.clear();
                }
              }),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.question.isPending)
            Row(
              children: [
                TextButton(
                  onPressed: _enabled ? () => _submit('cancel') : null,
                  child: Text(l.cancel),
                ),
                const Spacer(),
                FilledButton(
                  onPressed:
                      _enabled &&
                          widget.question.questions.every((f) {
                            final value = _answer[f.id];
                            return value is List
                                ? value.isNotEmpty
                                : value is String && value.isNotEmpty;
                          })
                      ? () => _submit('submit')
                      : null,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.confirm),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
