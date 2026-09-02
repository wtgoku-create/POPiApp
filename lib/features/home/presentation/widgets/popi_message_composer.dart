import 'dart:math' as math;
import 'dart:typed_data';

import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/safe_area_provider.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

class PopiComposerImage {
  const PopiComposerImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class _InlineComposerImage {
  const _InlineComposerImage.bytes(this.bytes) : source = null;
  const _InlineComposerImage.network(this.source) : bytes = null;

  final Uint8List? bytes;
  final String? source;
}

class _ComposerImageSpanBuilder extends SpecialTextSpanBuilder {
  _ComposerImageSpanBuilder(this.images);

  final Map<int, _InlineComposerImage> images;

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    int? index,
  }) {
    if (isStart(flag, _ComposerImageSpecialText.flag)) {
      return _ComposerImageSpecialText(
        images,
        textStyle,
        start: index! - (_ComposerImageSpecialText.flag.length - 1),
      );
    }
    return null;
  }
}

class _ComposerImageSpecialText extends SpecialText {
  _ComposerImageSpecialText(
    this.images,
    TextStyle? textStyle, {
    required this.start,
  }) : super(flag, ']', textStyle);

  static const flag = '[popi-image:';
  final Map<int, _InlineComposerImage> images;
  final int start;

  @override
  InlineSpan finishText() {
    final token = toString();
    final id = int.tryParse(token.substring(flag.length, token.length - 1));
    final image = id == null ? null : images[id];
    if (image == null) return TextSpan(text: token, style: textStyle);
    return ExtendedWidgetSpan(
      start: start,
      actualText: token,
      deleteAll: true,
      alignment: PlaceholderAlignment.middle,
      child: _InlineImageWidget(image: image),
    );
  }
}

class _InlineImageWidget extends StatelessWidget {
  const _InlineImageWidget({required this.image});

  final _InlineComposerImage image;

  @override
  Widget build(BuildContext context) {
    final child = image.bytes != null
        ? Image.memory(
            image.bytes!,
            width: 24,
            height: 24,
            cacheWidth: 48,
            cacheHeight: 48,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          )
        : Image.network(
            image.source!,
            width: 24,
            height: 24,
            cacheWidth: 48,
            cacheHeight: 48,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          );
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: child,
        ),
      ),
    );
  }
}

class PopiMessageComposerController {
  PopiMessageComposerController({String initialText = ''})
      : textController = TextEditingController(text: initialText) {
    textController.selection =
        TextSelection.collapsed(offset: initialText.length);
    specialTextSpanBuilder = _ComposerImageSpanBuilder(_images);
    textNotifier.value = markdown;
    textController.addListener(_handleTextChanged);
  }

  final TextEditingController textController;
  late final SpecialTextSpanBuilder specialTextSpanBuilder;
  final Map<int, _InlineComposerImage> _images = {};
  int _nextImageId = 0;
  final ValueNotifier<String> textNotifier = ValueNotifier('');

  String get markdown =>
      textController.text.replaceAll(RegExp(r'\[popi-image:\d+\]'), '').trim();

  void _handleTextChanged() {
    final value = markdown;
    if (textNotifier.value != value) textNotifier.value = value;
  }

  void dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> setText(String value) async {
    _images.clear();
    textController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> insertImage(Uint8List bytes) async {
    _insertInlineImage(_InlineComposerImage.bytes(bytes));
  }

  Future<void> insertImageSource(String source) async {
    _insertInlineImage(_InlineComposerImage.network(source));
  }

  void _insertInlineImage(_InlineComposerImage image) {
    final selection = textController.selection.isValid
        ? textController.selection
        : TextSelection.collapsed(offset: textController.text.length);
    final start = selection.start.clamp(0, textController.text.length);
    final end = selection.end.clamp(start, textController.text.length);
    final id = _nextImageId++;
    final token = '[popi-image:$id]';
    _images[id] = image;
    final text = textController.text.replaceRange(start, end, token);
    textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  void dispose() {
    textController
      ..removeListener(_handleTextChanged)
      ..dispose();
    textNotifier.dispose();
  }
}

class PopiMessageComposer extends ConsumerStatefulWidget {
  const PopiMessageComposer({
    required this.controller,
    required this.selectedImages,
    required this.onAttachment,
    required this.onRemoveImage,
    required this.onHeightChanged,
    required this.onSubmitted,
    this.onMentionRequested,
    super.key,
  });

  final PopiMessageComposerController controller;
  final List<PopiComposerImage> selectedImages;
  final VoidCallback onAttachment;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onMentionRequested;

  @override
  ConsumerState<PopiMessageComposer> createState() =>
      _PopiMessageComposerState();
}

class _PopiMessageComposerState extends ConsumerState<PopiMessageComposer>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final AnimationController _composerAnimationController;
  final _sizeKey = GlobalKey();
  bool _hasFocus = false;
  int _focusRevision = 0;
  bool _mentionSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
    _composerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addStatusListener(_handleComposerAnimationStatus);
    widget.controller.textNotifier.addListener(_handleTextChanged);
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
    widget.controller.textNotifier.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    if (_mentionSheetOpen || !mounted) return;
    if (widget.controller.markdown.endsWith('@')) {
      _mentionSheetOpen = true;
      widget.onMentionRequested?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mentionSheetOpen = false;
      });
    }
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
    final l10n = AppLocalizations.of(context)!;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding =
        math.max(safeArea.bottom, keyboardHeight + 20).toDouble();
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
                      final expandedHeight = hasImages ? 220.0 : 158.0;
                      final contentHeight = _hasFocus ? expandedHeight : 60.0;
                      return ValueListenableBuilder<String>(
                        valueListenable: widget.controller.textNotifier,
                        builder: (context, text, _) {
                          final content = _ComposerContent(
                            isExpanded: _hasFocus,
                            hasText: text.isNotEmpty,
                            images: widget.selectedImages,
                            input: _buildInput(
                              colorScheme,
                              placeholderFontSize: _hasFocus ? 14 : 16,
                            ),
                            colorScheme: colorScheme,
                            onAttachment: widget.onAttachment,
                            onRemoveImage: widget.onRemoveImage,
                            onKeepFocus: _focusNode.requestFocus,
                            onSubmitted: () => widget.onSubmitted(text),
                          );
                          return AnimatedBuilder(
                            animation: _composerAnimationController,
                            builder: (context, _) {
                              final progress = Curves.easeInOutCubic.transform(
                                _composerAnimationController.value,
                              );
                              final height =
                                  60 + (expandedHeight - 60) * progress;
                              final radius = AppRadii.pill +
                                  (AppRadii.card - AppRadii.pill) * progress;
                              final borderRadius =
                                  BorderRadius.circular(radius);
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
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.aiDisclaimer,
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
    final l10n = AppLocalizations.of(context)!;
    final placeholderStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: placeholderFontSize,
      fontWeight: FontWeight.w400,
    );
    return ExtendedTextField(
      key: const Key('popi-message-input'),
      focusNode: _focusNode,
      controller: widget.controller.textController,
      specialTextSpanBuilder: widget.controller.specialTextSpanBuilder,
      minLines: 1,
      maxLines: 4,
      cursorColor: colorScheme.primary,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: l10n.composerPlaceholder,
        hintStyle: placeholderStyle,
      ),
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
    final l10n = AppLocalizations.of(context)!;
    final isCompact = size <= 28;
    final buttonSize = isCompact ? 18.0 : 24.0;
    final buttonInset = isCompact ? 2.0 : 3.0;
    final iconSize = isCompact ? 13.0 : 17.0;
    return Semantics(
      label: l10n.selectedImageLabel(image.name),
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
                      tooltip: l10n.removeImage,
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
    required this.hasText,
    required this.images,
    required this.input,
    required this.colorScheme,
    required this.onAttachment,
    required this.onRemoveImage,
    required this.onKeepFocus,
    required this.onSubmitted,
  });

  final bool isExpanded;
  final bool hasText;
  final List<PopiComposerImage> images;
  final Widget input;
  final ColorScheme colorScheme;
  final VoidCallback onAttachment;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onKeepFocus;
  final VoidCallback onSubmitted;

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
                    ? EdgeInsets.only(
                        top: 66,
                        bottom: 50,
                      )
                    : EdgeInsets.only(left: 58 + compactImageStripWidth)
                : isExpanded
                    ? const EdgeInsets.only(bottom: 50)
                    : const EdgeInsets.only(left: 50),
            child: Align(
              alignment: isExpanded ? Alignment.topLeft : Alignment.centerLeft,
              child: SizedBox(
                width: double.infinity,
                height: isExpanded ? 84 : 24,
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
        Positioned(
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !isExpanded,
            child: AnimatedOpacity(
              duration: duration,
              curve: curve,
              opacity: isExpanded ? 1 : 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VoiceButton(
                    color: colorScheme.primary,
                    onPressed: onKeepFocus,
                  ),
                  if (hasText) const SizedBox(width: 8),
                  AnimatedSize(
                    duration: duration,
                    curve: curve,
                    child: hasText
                        ? _SendButton(onPressed: onSubmitted)
                        : const SizedBox.shrink(),
                  ),
                ],
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
    final l10n = AppLocalizations.of(context)!;
    return CustomPaint(
      painter: _DashedCircleBorderPainter(color: color),
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          tooltip: l10n.addAttachment,
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
    final l10n = AppLocalizations.of(context)!;
    return CustomPaint(
      painter: _DashedCircleBorderPainter(color: color),
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          tooltip: l10n.voiceInput,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(Icons.mic_none_rounded, size: 18, color: color),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        key: const Key('popi-send-button'),
        tooltip: AppLocalizations.of(context)!.sendMessage,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF6F47F5),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
        onPressed: onPressed,
        icon: AppSvgIcon.asset(
          'home_composer_send',
          size: 25,
          color: Colors.white,
          semanticsLabel: AppLocalizations.of(context)!.sendMessage,
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
