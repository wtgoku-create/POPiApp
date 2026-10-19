import 'package:flutter/material.dart';

/// Conversation surfaces and type from the POPi mobile conversation design.
abstract final class ConversationStyle {
  static const background = Color(0xFFF5F4FA);
  static const cardRadius = 26.0;
  static const message = TextStyle(
    fontSize: 18,
    height: 29 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const userMessage = TextStyle(
    fontSize: 18,
    height: 25 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const progressTitle = TextStyle(
    fontSize: 18,
    height: 25 / 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static Color pageColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? background
      : Theme.of(context).colorScheme.surface;

  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? const Color(0x80FFFFFF)
      : Theme.of(context).colorScheme.surfaceContainerLow;

  static Color userBubbleColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? const Color(0x0D6F47F5)
      : Theme.of(context).colorScheme.primary.withValues(alpha: .12);
}
