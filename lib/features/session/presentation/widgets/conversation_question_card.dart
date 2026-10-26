import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/conversation_snapshot.dart';
import 'conversation_card.dart';

/// The same answer form is used by conversation blocks and native DSH questions.
class ConversationQuestionCard extends StatefulWidget {
  const ConversationQuestionCard({
    required this.title,
    required this.fields,
    required this.onRespond,
    this.status = 'pending',
    this.answer = const {},
    this.busy = false,
    this.instantSingleChoice = false,
    super.key,
  });

  final String title;
  final List<ConversationQuestionField> fields;
  final Future<bool> Function(String action, Map<String, Object?> answer)
  onRespond;
  final String status;
  final Map<String, Object?> answer;
  final bool busy;
  final bool instantSingleChoice;

  @override
  State<ConversationQuestionCard> createState() =>
      _ConversationQuestionCardState();
}

class _ConversationQuestionCardState extends State<ConversationQuestionCard>
    with AutomaticKeepAliveClientMixin {
  final _answers = <String, Object?>{};
  final _custom = <String, String>{};
  final _customControllers = <String, TextEditingController>{};
  final _expanded = <String>{};
  bool _submitting = false;
  bool _submitted = false;

  @override
  bool get wantKeepAlive => true;

  bool get _settled => widget.status != 'pending';
  bool get _disabled => _settled || _submitted || _submitting || widget.busy;
  bool get _instant =>
      widget.instantSingleChoice &&
      widget.fields.length == 1 &&
      !widget.fields.single.multiple &&
      widget.fields.single.options.isNotEmpty;

  Map<String, Object?> get _values => {
    for (final field in widget.fields)
      if (_answers[field.id] != null ||
          (_custom[field.id]?.trim().isNotEmpty ?? false))
        field.id: field.multiple
            ? [
                ...?_answers[field.id] as List<String>?,
                if (_custom[field.id]?.trim().isNotEmpty ?? false)
                  _custom[field.id]!.trim(),
              ]
            : (_custom[field.id]?.trim().isNotEmpty ?? false)
            ? _custom[field.id]!.trim()
            : _answers[field.id],
  };

  bool get _valid =>
      widget.fields.isNotEmpty &&
      widget.fields.every(
        (field) =>
            !field.required ||
            (field.multiple
                ? (_values[field.id] as List?)?.isNotEmpty == true
                : (_values[field.id] as String?)?.isNotEmpty == true),
      );

  @override
  void dispose() {
    for (final controller in _customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _selected(ConversationQuestionField field) {
    final value = _settled ? widget.answer[field.id] : _answers[field.id];
    return value is List
        ? value.whereType<String>().toList()
        : value is String
        ? [value]
        : const [];
  }

  void _select(ConversationQuestionField field, String option) {
    if (_disabled) return;
    setState(() {
      if (field.multiple) {
        final selected = [..._selected(field)];
        selected.contains(option)
            ? selected.remove(option)
            : selected.add(option);
        _answers[field.id] = selected;
      } else {
        _answers[field.id] = option;
        _custom.remove(field.id);
        _customControllers[field.id]?.clear();
      }
    });
    if (_instant) _respond('submit');
  }

  Future<void> _respond(String action) async {
    if (_disabled || action == 'submit' && !_valid) return;
    setState(() => _submitting = true);
    try {
      final success = await widget.onRespond(action, _values);
      if (success && mounted) setState(() => _submitted = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final neutral = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF2F2F2)
        : scheme.surfaceContainerHigh;
    final title = widget.title.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConversationCard(
          framed: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(title, style: ConversationCardTypography.title),
                ),
              for (final (index, field) in widget.fields.indexed) ...[
                if (index > 0) const SizedBox(height: 20),
                if (field.label.isNotEmpty &&
                    (widget.fields.length != 1 || field.label != title))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      field.label,
                      style: ConversationCardTypography.title,
                    ),
                  ),
                for (final (optionIndex, option) in field.options.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _QuestionOption(
                      letter: optionIndex < 26
                          ? String.fromCharCode(65 + optionIndex)
                          : '${optionIndex + 1}',
                      label: option,
                      description: field.optionDescriptions[option] ?? '',
                      selected: _selected(field).contains(option),
                      busy: _submitting && _selected(field).contains(option),
                      neutral: neutral,
                      onTap: _disabled ? null : () => _select(field, option),
                    ),
                  ),
                if (!_settled &&
                    (!widget.instantSingleChoice ||
                        _expanded.contains(field.id) ||
                        field.options.isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextFormField(
                      controller: _customControllers.putIfAbsent(
                        field.id,
                        TextEditingController.new,
                      ),
                      enabled: !_disabled,
                      maxLength: 8000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: l10n.chatCustomAnswer,
                        counterText: '',
                      ),
                      onChanged: (value) => setState(() {
                        _custom[field.id] = value;
                        if (!field.multiple && value.trim().isNotEmpty) {
                          _answers.remove(field.id);
                        }
                      }),
                    ),
                  ),
                if (_settled)
                  for (final custom in _selected(
                    field,
                  ).where((value) => !field.options.contains(value)))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(custom),
                    ),
                if (!_settled &&
                    widget.instantSingleChoice &&
                    !_expanded.contains(field.id) &&
                    field.options.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _disabled
                          ? null
                          : () => setState(() => _expanded.add(field.id)),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      child: Text(l10n.chatCustomAnswer),
                    ),
                  ),
              ],
              if (_settled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    conversationStatusLabel(widget.status, l10n),
                    style: ConversationCardTypography.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (!_instant || _expanded.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: _disabled ? null : () => _respond('cancel'),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: _disabled || !_valid
                            ? null
                            : () => _respond('submit'),
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.confirm),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionOption extends StatelessWidget {
  const _QuestionOption({
    required this.letter,
    required this.label,
    required this.description,
    required this.selected,
    required this.busy,
    required this.neutral,
    required this.onTap,
  });

  final String letter;
  final String label;
  final String description;
  final bool selected;
  final bool busy;
  final Color neutral;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        color: selected ? neutral : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          hoverColor: neutral,
          focusColor: neutral,
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: neutral,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: ConversationCardTypography.caption.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (busy) ...[
                    const SizedBox(width: 8),
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ] else if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
