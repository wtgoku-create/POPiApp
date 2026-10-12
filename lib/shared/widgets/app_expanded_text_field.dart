import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../type/account_input_type.dart';
import 'app_sheet.dart';
import 'popi_expanded_message_editor.dart';

/// Custom answers use the same expanded editing surface as the chat composer.
class AppExpandedTextField extends StatefulWidget {
  const AppExpandedTextField({
    required this.controller,
    required this.hint,
    this.limit = AccountInputLimits.customCharacters,
    this.maxBytes,
    this.nickname = false,
    this.readOnly = false,
    this.editInSheet = true,
    this.fieldKey,
    this.focusNode,
    this.onSubmitted,
    this.trailing,
    this.editorInputKey = const Key('app-expanded-input'),
    this.editorConfirmKey = const Key('app-expanded-editor-confirm'),
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final int limit;
  final int? maxBytes;
  final bool nickname;
  final bool readOnly;
  final bool editInSheet;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final Key editorInputKey;
  final Key editorConfirmKey;

  @override
  State<AppExpandedTextField> createState() => _AppExpandedTextFieldState();
}

class _AppExpandedTextFieldState extends State<AppExpandedTextField> {
  bool _editorOpen = false;

  List<TextInputFormatter>? get _byteLimit {
    final limit = widget.maxBytes;
    if (limit == null) return null;
    return [
      TextInputFormatter.withFunction(
        (oldValue, newValue) =>
            utf8.encode(newValue.text).length <= limit ? newValue : oldValue,
      ),
    ];
  }

  Future<void> _openEditor() async {
    if (_editorOpen || widget.readOnly) return;
    _editorOpen = true;
    try {
      await AppSheet.show<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        shape: PopiExpandedMessageEditor.shape,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: PopiExpandedMessageEditor(
            input: TextField(
              key: widget.editorInputKey,
              controller: widget.controller,
              autofocus: true,
              expands: true,
              maxLines: null,
              maxLength: widget.limit,
              inputFormatters: _byteLimit,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: TextStyle(
                fontSize: 18,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            action: SizedBox.square(
              dimension: 40,
              child: IconButton(
                key: widget.editorConfirmKey,
                tooltip: AppLocalizations.of(context)!.confirm,
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.primary,
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded, size: 28),
              ),
            ),
          ),
        ),
      );
    } finally {
      _editorOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) => TextField(
        key: widget.fieldKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly || widget.editInSheet,
        canRequestFocus: !widget.readOnly && !widget.editInSheet,
        enableInteractiveSelection: !widget.editInSheet,
        onTap: widget.editInSheet && !widget.readOnly ? _openEditor : null,
        maxLength: widget.limit,
        inputFormatters: _byteLimit,
        maxLines: 1,
        style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.4),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) {
          FocusScope.of(context).unfocus();
          widget.onSubmitted?.call(value);
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
          filled: true,
          fillColor: dark
              ? colors.surfaceContainerHigh
              : widget.nickname
              ? const Color(0xFFF8F6FD)
              : const Color(0xFFF0F4F9),
          counterText: '',
          suffixIconConstraints: const BoxConstraints(
            minWidth: 54,
            minHeight: 50,
          ),
          suffixIcon: Padding(
            padding: EdgeInsets.only(right: widget.trailing == null ? 20 : 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.text.characters.length}/${widget.limit}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(100)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(100)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
      ),
    );
  }
}
