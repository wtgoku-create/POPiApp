import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../shared/providers/safe_area_provider.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

class PopiMessageComposer extends ConsumerWidget {
  const PopiMessageComposer({
    required this.controller,
    required this.onAttachment,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onAttachment;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = keyboardHeight > 0
        ? keyboardHeight + 20
        : math.max(safeArea.bottom, 20).toDouble();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        math.max(safeArea.left, 20),
        8,
        math.max(safeArea.right, 20),
        bottomPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 370),
          child: Container(
            key: const Key('popi-message-composer'),
            height: 60,
            padding: const EdgeInsets.only(left: 20, right: 10),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surfaceContainerHigh : null,
              gradient: isDark
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.pageBackground, AppColors.surface],
                    ),
              border: isDark
                  ? Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    )
                  : Border.all(color: AppColors.surface, width: 2),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: isDark ? 14 : 20,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('popi-message-input'),
                    controller: controller,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    cursorColor: colorScheme.primary,
                    textInputAction: TextInputAction.send,
                    onSubmitted: onSubmitted,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: '跟POPi说点什么...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _DashedCircleBorderPainter(
                    color: colorScheme.primary,
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: IconButton(
                      tooltip: '添加附件',
                      padding: EdgeInsets.zero,
                      onPressed: onAttachment,
                      icon: AppSvgIcon.asset(
                        'popi_add',
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCircleBorderPainter extends CustomPainter {
  const _DashedCircleBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Offset.zero & size;
    final borderRect = rect.deflate(.5);
    const dashCount = 20;
    final step = math.pi * 2 / dashCount;
    for (var index = 0; index < dashCount; index++) {
      canvas.drawArc(borderRect, index * step, step * .58, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircleBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
