import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared layout for the guide's scrollable selection and reading sheets.
class RoleGuideSheet extends StatelessWidget {
  const RoleGuideSheet({
    required this.title,
    required this.builder,
    this.actions,
    this.footer,
    this.initialSize = .845,
    super.key,
  });

  final String title;
  final Widget Function(BuildContext, ScrollController) builder;
  final List<Widget>? actions;
  final Widget? footer;
  final double initialSize;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: initialSize,
    minChildSize: .5,
    maxChildSize: .96,
    expand: false,
    builder: (context, controller) => Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        textAlign: actions == null
                            ? TextAlign.center
                            : TextAlign.start,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...?actions,
                  ],
                ),
              ),
              Expanded(child: builder(context, controller)),
              if (footer != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    15,
                    20,
                    math.max(20, MediaQuery.paddingOf(context).bottom),
                  ),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
