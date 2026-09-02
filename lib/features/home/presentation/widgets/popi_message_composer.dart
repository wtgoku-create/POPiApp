import 'dart:math' as math;
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../shared/providers/safe_area_provider.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

class PopiComposerImage {
  const PopiComposerImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class PopiMessageComposerController {
  PopiMessageComposerController({String initialText = ''})
      : editorState = EditorState(
          document: Document.blank(withInitialText: false)
            ..insert([0], [paragraphNode(text: initialText)]),
        );

  final EditorState editorState;

  String get markdown => documentToMarkdown(editorState.document).trim();

  void dismissKeyboard() {
    editorState.selection = null;
    editorState.service.keyboardService?.closeKeyboard();
    editorState.service.keyboardService?.disable();
  }

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
    required this.selectedImages,
    required this.onAttachment,
    required this.onRemoveImage,
    required this.onHeightChanged,
    required this.onSubmitted,
    super.key,
  });

  final PopiMessageComposerController controller;
  final List<PopiComposerImage> selectedImages;
  final VoidCallback onAttachment;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<String> onSubmitted;

  @override
  ConsumerState<PopiMessageComposer> createState() =>
      _PopiMessageComposerState();
}

class _PopiMessageComposerState extends ConsumerState<PopiMessageComposer>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final EditorScrollController _editorScrollController;
  late final AnimationController _composerAnimationController;
  final _sizeKey = GlobalKey();
  bool _hasFocus = false;
  int _focusRevision = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
    _composerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addStatusListener(_handleComposerAnimationStatus);
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
    _composerAnimationController
      ..removeStatusListener(_handleComposerAnimationStatus)
      ..dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final revision = ++_focusRevision;
    if (_focusNode.hasFocus) {
      if (mounted && !_hasFocus) {
        setState(() => _hasFocus = true);
        _composerAnimationController.forward();
      }
      return;
    }

    // AppFlowy removes its caret and selection overlays during the next frame.
    // Keep the editor constraints stable until that cleanup layout is complete.
    widget.controller.editorState.selection = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _focusNode.hasFocus ||
          revision != _focusRevision ||
          !_hasFocus) {
        return;
      }
      setState(() => _hasFocus = false);
      _composerAnimationController.reverse();
    });
  }

  void _dismissEditor() {
    widget.controller.dismissKeyboard();
    _focusNode.unfocus();
  }

  void _reportHeight() {
    if (!mounted) return;
    final renderBox = _sizeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox?.hasSize ?? false) {
      widget.onHeightChanged(renderBox!.size.height);
    }
  }

  void _handleComposerAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
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
    final hasImages = widget.selectedImages.isNotEmpty;
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        if (!_composerAnimationController.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
        }
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: Padding(
          key: _sizeKey,
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final expandedHeight = hasImages ? 180.0 : 118.0;
                      final contentHeight = _hasFocus ? expandedHeight : 60.0;
                      final content = _ComposerContent(
                        isExpanded: _hasFocus,
                        images: widget.selectedImages,
                        input: _buildInput(
                          colorScheme,
                          placeholderFontSize: _hasFocus ? 14 : 16,
                        ),
                        colorScheme: colorScheme,
                        onAttachment: widget.onAttachment,
                        onRemoveImage: widget.onRemoveImage,
                        onKeepFocus: _focusNode.requestFocus,
                      );
                      return AnimatedBuilder(
                        animation: _composerAnimationController,
                        builder: (context, _) {
                          final progress = Curves.easeInOutCubic.transform(
                            _composerAnimationController.value,
                          );
                          final height = 60 + (expandedHeight - 60) * progress;
                          final radius = AppRadii.pill +
                              (AppRadii.card - AppRadii.pill) * progress;
                          final borderRadius = BorderRadius.circular(radius);
                          return TapRegion(
                            onTapOutside: (_) => _dismissEditor(),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _focusNode.requestFocus,
                              child: Container(
                                key: const Key('popi-message-composer'),
                                width: double.infinity,
                                height: height,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colorScheme.surfaceContainerHigh
                                      : null,
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
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: .45),
                                        )
                                      : Border.all(
                                          color: AppColors.surface,
                                          width: 2,
                                        ),
                                  borderRadius: borderRadius,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.2 : 0.05,
                                      ),
                                      blurRadius: isDark ? 14 : 20,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: borderRadius,
                                  child: OverflowBox(
                                    alignment: Alignment.topCenter,
                                    minWidth: constraints.maxWidth,
                                    maxWidth: constraints.maxWidth,
                                    minHeight: contentHeight,
                                    maxHeight: contentHeight,
                                    child: Padding(
                                      padding: _hasFocus
                                          ? const EdgeInsets.all(10)
                                          : const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                      child: content,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
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
    final placeholderStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: placeholderFontSize,
      fontWeight: FontWeight.w400,
    );
    final blockComponentBuilders = {
      ...standardBlockComponentBuilderMap,
      ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
        configuration: BlockComponentConfiguration(
          padding: (_) => EdgeInsets.zero,
          placeholderText: (_) => '跟POPi说点什么...',
          placeholderTextStyle: (_, {textSpan}) => placeholderStyle,
        ),
      )..showActions = (_) => false,
    };

    return Stack(
      children: [
        Positioned.fill(
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
        ),
        if (!_hasFocus && widget.controller.markdown.isEmpty)
          IgnorePointer(
            child: Text(
              '跟POPi说点什么...',
              key: const Key('popi-message-placeholder'),
              style: placeholderStyle,
            ),
          ),
      ],
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({
    required this.image,
    required this.index,
    required this.size,
    required this.onRemove,
  });

  final PopiComposerImage image;
  final int index;
  final double size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = size <= 28;
    final buttonSize = isCompact ? 18.0 : 24.0;
    final buttonInset = isCompact ? 2.0 : 3.0;
    final iconSize = isCompact ? 13.0 : 17.0;
    return Semantics(
      label: '已选择图片：${image.name}',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.small),
                child: Image.memory(
                  image.bytes,
                  key: Key('popi-selected-image-$index'),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
            if (!isCompact)
              Positioned(
                top: buttonInset,
                right: buttonInset,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.scrim.withValues(alpha: .82),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .9),
                        width: .8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .28),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      key: Key('popi-remove-selected-image-$index'),
                      tooltip: '移除图片',
                      constraints: BoxConstraints.tightFor(
                        width: buttonSize,
                        height: buttonSize,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.square(buttonSize),
                        maximumSize: Size.square(buttonSize),
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onRemove,
                      icon: Icon(
                        Icons.close_rounded,
                        size: iconSize,
                        color: Colors.white,
                      ),
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

class _ComposerContent extends StatelessWidget {
  const _ComposerContent({
    required this.isExpanded,
    required this.images,
    required this.input,
    required this.colorScheme,
    required this.onAttachment,
    required this.onRemoveImage,
    required this.onKeepFocus,
  });

  final bool isExpanded;
  final List<PopiComposerImage> images;
  final Widget input;
  final ColorScheme colorScheme;
  final VoidCallback onAttachment;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onKeepFocus;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);
    const curve = Curves.easeOutCubic;
    final hasImages = images.isNotEmpty;
    final compactImageStripWidth =
        images.isEmpty ? 0.0 : images.length * 28.0 + (images.length - 1) * 6.0;
    return Stack(
      children: [
        if (hasImages)
          Positioned(
            top: isExpanded ? 0 : 16,
            left: isExpanded ? 0 : 50,
            right: isExpanded ? 0 : null,
            width: isExpanded ? null : compactImageStripWidth,
            height: isExpanded ? 58 : 28,
            child: ListView.separated(
              key: const Key('popi-selected-images'),
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => SizedBox(
                width: isExpanded ? 8 : 6,
              ),
              itemBuilder: (context, index) => _SelectedImagePreview(
                image: images[index],
                index: index,
                size: isExpanded ? 58 : 28,
                onRemove: () => onRemoveImage(index),
              ),
            ),
          ),
        Positioned.fill(
          child: Padding(
            padding: hasImages
                ? isExpanded
                    ? const EdgeInsets.only(top: 66, bottom: 50)
                    : EdgeInsets.only(left: 58 + compactImageStripWidth)
                : isExpanded
                    ? const EdgeInsets.only(bottom: 50)
                    : const EdgeInsets.only(left: 50),
            child: Align(
              alignment: isExpanded ? Alignment.topLeft : Alignment.centerLeft,
              child: SizedBox(
                width: double.infinity,
                height: isExpanded ? 44 : 24,
                child: input,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: isExpanded ? null : 10,
          bottom: isExpanded ? 0 : null,
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
