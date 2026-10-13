import 'package:flutter/material.dart';

/// Mobile touch taps outside a text field dismiss its keyboard as on desktop.
class AppKeyboardDismiss extends StatelessWidget {
  const AppKeyboardDismiss({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      EditableTextTapOutsideIntent:
          CallbackAction<EditableTextTapOutsideIntent>(
            onInvoke: (intent) {
              intent.focusNode.unfocus();
              return null;
            },
          ),
    },
    child: child,
  );
}
