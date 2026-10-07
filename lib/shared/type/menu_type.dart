import 'package:flutter/material.dart';

/// Describes a row in the shared popup menu.
@immutable
sealed class AppMenuEntry {
  const AppMenuEntry({this.key});

  final Key? key;
}

/// An action; a null callback or [enabled] set to false disables the row.
final class AppMenuItem extends AppMenuEntry {
  const AppMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.enabled = true,
    this.selected = false,
    this.destructive = false,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final VoidCallback? onSelected;

  /// The action symbol displayed at the trailing edge of the row.
  final Widget? icon;
  final bool enabled;
  final bool selected;
  final bool destructive;
  final Color? foregroundColor;
}

/// A nested menu using the same appearance and interaction as its parent.
final class AppSubmenu extends AppMenuEntry {
  const AppSubmenu({
    required this.label,
    required this.entries,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final List<AppMenuEntry> entries;

  /// The action symbol displayed before the submenu chevron.
  final Widget? icon;
  final bool enabled;
}

/// Separates related groups of menu actions.
final class AppMenuDivider extends AppMenuEntry {
  const AppMenuDivider({this.color, super.key});

  final Color? color;
}
