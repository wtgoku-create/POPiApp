import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../shared/providers/safe_area_provider.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

class PopiMessageComposerController {
  PopiMessageComposerController({String initialText = ''})
      : editorState = EditorState(
          document: Document.blank(withInitialText: false)
            ..insert([0], [paragraphNode(text: initialText)]),
        );

  final EditorState editorState;

  String get markdown => documentToMarkdown(editorState.document).trim();

  Future<void> setText(String value) async {
    final transaction = editorState.transaction;
    final children = editorState.document.root.children.toList();
    if (children.isNotEmpty) {
      transaction.deleteNodes(children);
    }
    transaction.insertNode([0], paragraphNode(text: value));
    transaction.afterSelection = Selection.collapsed(
      Position(path: const [0], offset: value.length),
    );
    await editorState.apply(transaction);
  }

  void dispose() => editorState.dispose();
}

class PopiMessageComposer extends ConsumerStatefulWidget {
  const PopiMessageComposer({
    required this.controller,
    required this.onAttachment,
    required this.onHeightChanged,
    required this.onSubmitted,
    super.key,
  });

  final PopiMessageComposerController controller;
  final VoidCallback onAttachment;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<String> onSubmitted;

  @override
  ConsumerState<PopiMessageComposer> createState() =>
      _PopiMessageComposerState();
}

class _PopiMessageComposerState extends ConsumerState<PopiMessageComposer> {
  late final FocusNode _focusNode;
  late final EditorScrollController _editorScrollController;
  final _sizeKey = GlobalKey();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
    _editorScrollController = EditorScrollController(
      editorState: widget.controller.editorState,
      shrinkWrap: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() => _isExpanded = _focusNode.hasFocus);
  }

  void _reportHeight() {
    if (!mounted) return;
    final renderBox = _sizeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox?.hasSize ?? false) {
      widget.onHeightChanged(renderBox!.size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = keyboardHeight > 0
        ? keyboardHeight + 20
        : math.max(safeArea.bottom, 20).toDouble();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: AnimatedPadding(
          key: _sizeKey,
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
              // Figma's 376px measurement is the content box. The visible frame
              // also includes 10px padding and a 2px border on each side.
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    key: const Key('popi-message-composer'),
                    width: double.infinity,
                    // The focused design has a 94px content area, plus 10px
                    // padding and a 2px border on both vertical sides.
                    height: _isExpanded ? 118 : 60,
                    padding: _isExpanded
                        ? const EdgeInsets.all(10)
                        : const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? colorScheme.surfaceContainerHigh : null,
                      gradient: isDark
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.pageBackground,
                                AppColors.surface,
                              ],
                            ),
                      border: isDark
                          ? Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: .45,
                              ),
                            )
                          : Border.all(color: AppColors.surface, width: 2),
                      borderRadius: BorderRadius.circular(
                        _isExpanded ? AppRadii.card : AppRadii.pill,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: isDark ? 14 : 20,
                        ),
                      ],
                    ),
                    child: _ComposerContent(
                      isExpanded: _isExpanded,
                      input: _buildInput(
                        colorScheme,
                        placeholderFontSize: _isExpanded ? 14 : 16,
                      ),
                      colorScheme: colorScheme,
                      onAttachment: widget.onAttachment,
                      onKeepFocus: _focusNode.requestFocus,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'AI生成结果可能有误，仅供参考',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    ColorScheme colorScheme, {
    required double placeholderFontSize,
  }) {
    final blockComponentBuilders = {
      ...standardBlockComponentBuilderMap,
      ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
        configuration: BlockComponentConfiguration(
          padding: (_) => EdgeInsets.zero,
          placeholderText: (_) => '跟POPi说点什么...',
          placeholderTextStyle: (_, {textSpan}) => TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: placeholderFontSize,
            fontWeight: FontWeight.w400,
          ),
        ),
      )..showActions = (_) => false,
    };

    return TapRegion(
      onTapOutside: (_) => _focusNode.unfocus(),
      child: AppFlowyEditor(
        key: const Key('popi-message-input'),
        editorState: widget.controller.editorState,
        editorScrollController: _editorScrollController,
        focusNode: _focusNode,
        shrinkWrap: true,
        showMagnifier: true,
        autoScrollEdgeOffset: 24,
        blockComponentBuilders: blockComponentBuilders,
        editorStyle: EditorStyle.mobile(
          padding: EdgeInsets.zero,
          cursorColor: colorScheme.primary,
          dragHandleColor: colorScheme.primary,
          selectionColor: colorScheme.primary.withValues(alpha: .18),
          textStyleConfiguration: TextStyleConfiguration(
            text: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerContent extends StatelessWidget {
  const _ComposerContent({
    required this.isExpanded,
    required this.input,
    required this.colorScheme,
    required this.onAttachment,
    required this.onKeepFocus,
  });

  final bool isExpanded;
  final Widget input;
  final ColorScheme colorScheme;
  final VoidCallback onAttachment;
  final VoidCallback onKeepFocus;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);
    const curve = Curves.easeOutCubic;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedPadding(
            duration: duration,
            curve: curve,
            padding: isExpanded
                ? const EdgeInsets.only(bottom: 50)
                : const EdgeInsets.only(left: 50),
            child: AnimatedAlign(
              duration: duration,
              curve: curve,
              alignment: isExpanded ? Alignment.topLeft : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: duration,
                curve: curve,
                width: double.infinity,
                height: isExpanded ? 44 : 24,
                child: input,
              ),
            ),
          ),
        ),
        AnimatedAlign(
          duration: duration,
          curve: curve,
          alignment: isExpanded ? Alignment.bottomLeft : Alignment.centerLeft,
          child: _AttachmentButton(
            color: colorScheme.primary,
            onPressed: onAttachment,
          ),
        ),
        IgnorePointer(
          ignoring: !isExpanded,
          child: AnimatedOpacity(
            duration: duration,
            curve: curve,
            opacity: isExpanded ? 1 : 0,
            child: Align(
              alignment: Alignment.bottomRight,
              child: _VoiceButton(
                color: colorScheme.primary,
                onPressed: onKeepFocus,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({
    required this.color,
    required this.onPressed,
  });

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCircleBorderPainter(color: color),
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          tooltip: '添加附件',
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: AppSvgIcon.asset(
            'home_composer_attachment',
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCircleBorderPainter(color: color),
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          tooltip: '语音输入',
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(Icons.mic_none_rounded, size: 18, color: color),
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
