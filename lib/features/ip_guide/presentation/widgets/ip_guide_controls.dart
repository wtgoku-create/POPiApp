import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/popi_expanded_message_editor.dart';

/// Shared next action with the pill shape and exported chevron from the design.
class IpGuideNextButton extends StatelessWidget {
  const IpGuideNextButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

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

/// Custom answers use the same expanded editing surface as the chat composer.
class IpGuideTextField extends StatefulWidget {
  const IpGuideTextField({
    required this.controller,
    required this.hint,
    this.limit = 50,
    this.nickname = false,
    this.readOnly = false,
    this.editInSheet = true,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final int limit;
  final bool nickname;
  final bool readOnly;
  final bool editInSheet;

  @override
  State<IpGuideTextField> createState() => _IpGuideTextFieldState();
}

class _IpGuideTextFieldState extends State<IpGuideTextField> {
  bool _editorOpen = false;

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
              key: const Key('ip-guide-expanded-input'),
              controller: widget.controller,
              autofocus: true,
              expands: true,
              maxLines: null,
              maxLength: widget.limit,
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
              child: IconButton.filled(
                key: const Key('ip-guide-editor-confirm'),
                tooltip: AppLocalizations.of(context)!.confirm,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded),
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
        controller: widget.controller,
        readOnly: widget.readOnly || widget.editInSheet,
        canRequestFocus: !widget.readOnly && !widget.editInSheet,
        enableInteractiveSelection: !widget.editInSheet,
        onTap: widget.editInSheet && !widget.readOnly ? _openEditor : null,
        maxLength: widget.limit,
        maxLines: 1,
        style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.4),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
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
            padding: const EdgeInsets.only(right: 20),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                '${value.text.characters.length}/${widget.limit}',
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              ),
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
