import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_svg_icon.dart';

/// Provides the Figma long-message editing surface above the keyboard.
class PopiExpandedMessageEditor extends StatelessWidget {
  const PopiExpandedMessageEditor({
    required this.input,
    required this.action,
    super.key,
  });

  final Widget input;
  final Widget action;

  static const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: shape.borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: ColoredBox(
          key: const Key('popi-expanded-editor'),
          color: colors.surface.withValues(alpha: .9),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox.square(
                      dimension: 40,
                      child: IconButton(
                        key: const Key('popi-expanded-editor-close'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(false),
                        style: IconButton.styleFrom(
                          backgroundColor: dark
                              ? colors.surfaceContainerHighest
                              : const Color(0xFFEDEDED),
                        ),
                        icon: AppSvgIcon.asset(
                          'chat_editor_close',
                          size: 16,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    action,
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: input),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
