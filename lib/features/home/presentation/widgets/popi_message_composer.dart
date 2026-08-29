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
    required this.onMicrophone,
    required this.onSubmitted,
    this.microphoneActive = false,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onAttachment;
  final VoidCallback onMicrophone;
  final ValueChanged<String> onSubmitted;
  final bool microphoneActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = keyboardHeight > 0
        ? keyboardHeight + 20
        : math.max(safeArea.bottom, 20).toDouble();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        math.max(safeArea.left, 20),
        8,
        math.max(safeArea.right, 20),
        bottomPadding,
      ),
      child: Container(
        key: const Key('popi-message-composer'),
        height: 60,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.only(left: 20, right: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 5),
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
                cursorColor: AppColors.brand,
                textInputAction: TextInputAction.send,
                onSubmitted: onSubmitted,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: const InputDecoration(
                  hintText: '跟POPi说点什么...',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
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
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                tooltip: microphoneActive ? '关闭工具' : '打开工具',
                padding: EdgeInsets.zero,
                onPressed: onMicrophone,
                icon: const AppSvgIcon.asset(
                  'popi_composer_tools',
                  size: 40,
                ),
              ),
            ),
            CustomPaint(
              painter: const _DashedCircleBorderPainter(
                color: AppColors.brand,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    tooltip: '添加附件',
                    padding: EdgeInsets.zero,
                    onPressed: onAttachment,
                    color: AppColors.brand,
                    icon: const AppSvgIcon.asset('popi_add', size: 20),
                  ),
                ),
              ),
            ),
          ],
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
