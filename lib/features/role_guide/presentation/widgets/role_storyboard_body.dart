import 'package:flutter/material.dart';

import '../../domain/home_storyboard.dart';

/// Selectable prompt text preserves the same body and line breaks as Web.
class RoleStoryboardBody extends StatelessWidget {
  const RoleStoryboardBody({required this.body, this.style, super.key});

  final String body;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SelectableText(
      HomeStoryboard.displayText(body),
      style: (style ?? const TextStyle(fontSize: 16, height: 1.5)).copyWith(
        color: color,
      ),
    );
  }
}
