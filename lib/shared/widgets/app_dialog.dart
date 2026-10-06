import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AppDialog extends StatelessWidget {
  const AppDialog(
      {super.key,
      required this.child,
      this.width = 330,
      this.padding = const EdgeInsets.all(30)});

  final Widget child;
  final double width;
  final EdgeInsetsGeometry padding;

  static Future<T?> show<T>(
          {required BuildContext context, required WidgetBuilder builder}) =>
      showDialog<T>(
        context: context,
        builder: builder,
      );

  static Future<bool?> confirm(
          {required BuildContext context,
          required String title,
          required String description,
          required String cancelLabel,
          required String confirmLabel,
          Key? confirmKey,
          bool destructive = false}) =>
      show<bool>(
        context: context,
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return AppDialog(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 18,
                    height: 22 / 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 25),
            Text(description,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFF4F4F4F)
                        : colors.onSurfaceVariant,
                    fontSize: 16,
                    height: 1.3)),
            const SizedBox(height: 25),
            Row(children: [
              Expanded(
                  child: SizedBox(
                      height: 50,
                      child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  AppColors.brand.withValues(alpha: 0.05),
                              foregroundColor: colors.onSurface,
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              textStyle: const TextStyle(fontSize: 16)),
                          child:
                              Text(cancelLabel, textAlign: TextAlign.center)))),
              const SizedBox(width: 10),
              Expanded(
                  child: SizedBox(
                      height: 50,
                      child: FilledButton(
                          key: confirmKey,
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                              backgroundColor: destructive
                                  ? const Color(0xFFD63D43)
                                  : colors.primary,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              textStyle: const TextStyle(fontSize: 16)),
                          child: Text(confirmLabel,
                              textAlign: TextAlign.center)))),
            ]),
          ]));
        },
      );

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: SizedBox(
            width: width,
            child: SingleChildScrollView(
                child: Padding(padding: padding, child: child))),
      );
}
