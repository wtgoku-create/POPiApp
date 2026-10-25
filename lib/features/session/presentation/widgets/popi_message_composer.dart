import 'dart:async';
import 'dart:math' as math;

import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/providers/safe_area_provider.dart';
import '../../../../shared/providers/speech_input_provider.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/popi_expanded_message_editor.dart';
import '../../../assets/domain/library_role.dart';
import '../../../assets/domain/library_work.dart';
import '../../../assets/presentation/library_work_thumbnail.dart';
import '../../../role_guide/presentation/widgets/role_guide_controls.dart';
import '../composer_image_upload_controller.dart';
import '../composer_voice_input_controller.dart';

export '../composer_image_upload_controller.dart' show PopiComposerImage;

class _InlineComposerImage {
  const _InlineComposerImage.bytes(this.bytes);

  final Uint8List bytes;
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
    final child = Image.memory(
      image.bytes,
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
        child: ClipRRect(borderRadius: BorderRadius.circular(4), child: child),
      ),
    );
  }
}

class PopiMessageComposerController {
  PopiMessageComposerController({String initialText = ''})
    : textController = TextEditingController(text: initialText) {
    textController.selection = TextSelection.collapsed(
      offset: initialText.length,
    );
    specialTextSpanBuilder = _ComposerImageSpanBuilder(_images);
    textNotifier.value = markdown;
    textController.addListener(_handleTextChanged);
  }

  final TextEditingController textController;
  late final SpecialTextSpanBuilder specialTextSpanBuilder;
  final Map<int, _InlineComposerImage> _images = {};
  int _nextImageId = 0;
  final ValueNotifier<String> textNotifier = ValueNotifier('');
  VoidCallback? _requestInputFocus;

  String get markdown =>
      textController.text.replaceAll(RegExp(r'\[popi-image:\d+\]'), '').trim();

  void _handleTextChanged() {
    final value = markdown;
    if (textNotifier.value != value) textNotifier.value = value;
  }

  void dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Restores editing after a host picker closes without exposing FocusNode.
  void requestInputFocus() => _requestInputFocus?.call();

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
  /// Visual space above the safe edge or keyboard, shared by composer hosts.
  static const bottomGap = 8.0;

  const PopiMessageComposer({
    required this.controller,
    required this.selectedImages,
    required this.onAttachment,
    required this.onRemoveImage,
    required this.onHeightChanged,
    required this.onSubmitted,
    this.selectedRoles = const [],
    this.onRemoveRole,
    this.selectedAssets = const [],
    this.onRemoveAsset,
    this.onPreviewAsset,
    this.selectedAssetThumbnailBuilder,
    this.onRetryImage,
    this.attachmentsReady = true,
    this.onModelParametersRequested,
    this.modelParametersDescription = '',
    this.onMentionRequested,
    this.enableMentions = false,
    this.sending = false,
    this.running = false,
    this.conversationMode = false,
    this.sessionLayout = false,
    this.bottomPadding,
    this.maxWidth,
    this.placeholderText,
    this.active = true,
    this.onStop,
    this.onVoiceInput,
    this.castRoles,
    this.onCastRequested,
    this.castEnabled = true,
    super.key,
  });

  final PopiMessageComposerController controller;
  final List<PopiComposerImage> selectedImages;
  final List<LibraryRole> selectedRoles;
  final ValueChanged<int>? onRemoveRole;
  final List<LibraryWork> selectedAssets;
  final ValueChanged<int>? onRemoveAsset;
  final ValueChanged<int>? onPreviewAsset;
  final Widget? Function(BuildContext context, int index)?
  selectedAssetThumbnailBuilder;
  final VoidCallback onAttachment;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int>? onRetryImage;
  final bool attachmentsReady;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onModelParametersRequested;
  final String modelParametersDescription;
  final VoidCallback? onMentionRequested;

  /// Enables the host mention picker triggered by typing @.
  final bool enableMentions;
  final bool sending;
  final bool running;

  /// Active conversations use a wider editor and larger text.
  final bool conversationMode;

  /// Session screens use the compact Figma insets, including above the keyboard.
  final bool sessionLayout;

  /// Overrides the bottom inset when the host already handles safe areas.
  final double? bottomPadding;

  /// Lets a desktop conversation use the width of its content pane.
  final double? maxWidth;

  /// Lets the host address the named assistant instead of the generic brand.
  final String? placeholderText;

  /// Cached desktop editors must release input when another session is active.
  final bool active;
  final VoidCallback? onStop;

  /// Optional host override; otherwise uses the shared speech-to-text input.
  final VoidCallback? onVoiceInput;
  final List<LibraryRole>? castRoles;
  final VoidCallback? onCastRequested;
  final bool castEnabled;

  @override
  ConsumerState<PopiMessageComposer> createState() =>
      _PopiMessageComposerState();
}

class _PopiMessageComposerState extends ConsumerState<PopiMessageComposer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final FocusNode _focusNode;
  late final AnimationController _composerAnimationController;
  final _sizeKey = GlobalKey();
  final _inputScroll = ScrollController();
  late String _lastInputText;
  bool _isExpanded = false;
  int _focusRevision = 0;
  bool _mentionSheetOpen = false;
  bool _expandedEditorOpen = false;
  late ComposerVoiceInputController _voiceInput;
  late final ValueNotifier<
    ({bool sending, bool running, bool attachmentsReady})
  >
  _editorStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createVoiceInput();
    _editorStatus = ValueNotifier((
      sending: widget.sending,
      running: widget.running,
      attachmentsReady: widget.attachmentsReady,
    ));
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
    widget.controller._requestInputFocus = _focusInput;
    _isExpanded =
        widget.controller.textController.text.isNotEmpty ||
        widget.selectedRoles.isNotEmpty ||
        widget.selectedAssets.isNotEmpty;
    _composerAnimationController = AnimationController(
      vsync: this,
      value: _isExpanded ? 1 : 0,
      duration: const Duration(milliseconds: 220),
    )..addStatusListener(_handleComposerAnimationStatus);
    widget.controller.textController.addListener(_syncExpansion);
    _lastInputText = widget.controller.textController.text;
    widget.controller.textController.addListener(_revealInsertedText);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceInput
      ..removeListener(_voiceStateChanged)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _composerAnimationController
      ..removeStatusListener(_handleComposerAnimationStatus)
      ..dispose();
    widget.controller.textController.removeListener(_syncExpansion);
    widget.controller.textController.removeListener(_revealInsertedText);
    widget.controller._requestInputFocus = null;
    _inputScroll.dispose();
    _editorStatus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PopiMessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._requestInputFocus = null;
      _voiceInput
        ..removeListener(_voiceStateChanged)
        ..dispose();
      _createVoiceInput();
      oldWidget.controller.textController
        ..removeListener(_syncExpansion)
        ..removeListener(_revealInsertedText);
      widget.controller.textController
        ..addListener(_syncExpansion)
        ..addListener(_revealInsertedText);
      widget.controller._requestInputFocus = _focusInput;
      _lastInputText = '';
      _revealInsertedText();
    }
    if (widget.sending || widget.running || !widget.active) {
      _voiceInput.cancel();
    }
    if (oldWidget.active && !widget.active) _dismissEditor();
    _syncExpansion();
    if (oldWidget.sending != widget.sending ||
        oldWidget.running != widget.running ||
        oldWidget.attachmentsReady != widget.attachmentsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _editorStatus.value = (
            sending: widget.sending,
            running: widget.running,
            attachmentsReady: widget.attachmentsReady,
          );
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == false) _voiceInput.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _voiceInput.cancel();
    }
  }

  void _createVoiceInput() {
    _voiceInput = ComposerVoiceInputController(
      speechInput: ref.read(speechInputFactoryProvider)(),
      textController: widget.controller.textController,
      onError: _showVoiceError,
    )..addListener(_voiceStateChanged);
  }

  void _voiceStateChanged() {
    if (mounted) setState(() {});
  }

  void _showVoiceError(String code) {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    AppToast.error(context, switch (code) {
      'permission_denied' => l.voiceInputPermissionDenied,
      'unavailable' => l.voiceInputUnavailable,
      'no_speech' => l.voiceInputNoSpeech,
      'network' => l.voiceInputNetworkError,
      'audio' => l.voiceInputAudioError,
      _ => l.voiceInputFailed,
    });
  }

  void _toggleVoiceInput() {
    if (!widget.active || widget.sending || widget.running) return;
    if (widget.onVoiceInput case final override?) {
      override();
      return;
    }
    if (_voiceInput.active) {
      unawaited(_voiceInput.stop());
      return;
    }
    _dismissEditor();
    final locale = Localizations.localeOf(context);
    final language = locale.countryCode == null
        ? locale.languageCode == 'zh'
              ? 'zh-CN'
              : 'en-US'
        : locale.toLanguageTag();
    unawaited(_voiceInput.start(language));
  }

  void _submit(String text) {
    _voiceInput.cancel();
    widget.onSubmitted(text);
  }

  Future<void> _openExpandedEditor() async {
    if (widget.running) {
      _showRunningToast();
      return;
    }
    if (_expandedEditorOpen || widget.sending) return;
    _voiceInput.cancel();
    _expandedEditorOpen = true;
    try {
      final submitted = await AppSheet.show<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        shape: PopiExpandedMessageEditor.shape,
        builder: (sheetContext) => ValueListenableBuilder(
          valueListenable: _editorStatus,
          builder: (context, status, _) => ValueListenableBuilder(
            valueListenable: widget.controller.textController,
            builder: (context, value, _) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: PopiExpandedMessageEditor(
                input: _buildInput(
                  Theme.of(context).colorScheme,
                  placeholderFontSize: 18,
                  expandedEditor: true,
                  readOnly: status.sending,
                  running: status.running,
                ),
                action: _SendButton(
                  icon: Icons.check_rounded,
                  sending: status.sending,
                  running: status.running,
                  onPressed: status.sending
                      ? null
                      : status.running
                      ? widget.onStop
                      : !status.attachmentsReady
                      ? null
                      : widget.controller.markdown.isNotEmpty ||
                            widget.selectedImages.isNotEmpty ||
                            widget.selectedRoles.isNotEmpty ||
                            widget.selectedAssets.isNotEmpty
                      ? () => Navigator.of(sheetContext).pop(true)
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (submitted == true) {
        _dismissEditor();
        _submit(widget.controller.markdown);
      } else {
        _dismissEditor();
      }
    } finally {
      _expandedEditorOpen = false;
    }
  }

  void _revealInsertedText() {
    final value = widget.controller.textController.value;
    if (value.text == _lastInputText) return;
    _lastInputText = value.text;
    if (value.text.isEmpty ||
        !value.selection.isCollapsed ||
        value.selection.extentOffset != value.text.length ||
        _expandedEditorOpen) {
      return;
    }
    // Wait for wrapping and the expand-button inset to update the scroll extent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _expandedEditorOpen ||
          !_inputScroll.hasClients ||
          widget.controller.textController.value != value) {
        return;
      }
      _inputScroll.jumpTo(_inputScroll.position.maxScrollExtent);
    });
  }

  void _handleUserTextChanged(String rawText) {
    if (!widget.enableMentions ||
        _mentionSheetOpen ||
        !widget.active ||
        widget.sending ||
        widget.running ||
        _voiceInput.active ||
        !mounted) {
      return;
    }
    final selection = widget.controller.textController.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    final caret = selection.extentOffset;
    // onChanged is emitted only for user edits. Looking at the caret means an
    // @ typed in the middle of a draft works without reopening for setText or
    // a selection-only update.
    if (caret <= 0 || caret > rawText.length || rawText[caret - 1] != '@') {
      return;
    }
    _mentionSheetOpen = true;
    widget.onMentionRequested?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mentionSheetOpen = false;
    });
  }

  void _handleFocusChanged() {
    final revision = ++_focusRevision;
    if (_focusNode.hasFocus) {
      _syncExpansion();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusNode.hasFocus || revision != _focusRevision) {
        return;
      }
      _syncExpansion();
    });
  }

  void _syncExpansion() {
    if (!mounted) return;
    final expanded =
        _focusNode.hasFocus ||
        widget.controller.textController.text.isNotEmpty ||
        widget.selectedRoles.isNotEmpty ||
        widget.selectedAssets.isNotEmpty;
    if (expanded == _isExpanded) return;
    setState(() => _isExpanded = expanded);
    if (expanded) {
      _composerAnimationController.forward();
    } else {
      _composerAnimationController.reverse();
    }
  }

  void _dismissEditor() {
    widget.controller.dismissKeyboard();
    _focusNode.unfocus();
  }

  void _showRunningToast() {
    AppToast.info(context, AppLocalizations.of(context)!.composerRunning);
  }

  void _focusInput() {
    if (!widget.active || _voiceInput.active) return;
    if (widget.running) {
      _showRunningToast();
      return;
    }
    final editor = _focusNode.context
        ?.findAncestorStateOfType<ExtendedTextFieldState>()
        ?.editableTextKey
        .currentState;
    if (editor != null) {
      // Reopen the editing connection even when Flutter still holds focus.
      editor.requestKeyboard();
    } else {
      _focusNode.requestFocus();
    }
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
        widget.bottomPadding ??
        (math.max(safeArea.bottom - keyboardHeight, 0).toDouble() +
            PopiMessageComposer.bottomGap);
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
            math.max(safeArea.left, widget.sessionLayout ? 10 : 20),
            8,
            math.max(safeArea.right, widget.sessionLayout ? 10 : 20),
            bottomPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              // Figma's 376px measurement is the content box. The visible frame
              // also includes 10px padding and a 2px border on each side.
              constraints: BoxConstraints(
                maxWidth:
                    widget.maxWidth ?? (widget.conversationMode ? 640 : 400),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_voiceInput.active)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                switch (_voiceInput.state) {
                                  ComposerVoiceInputState.starting =>
                                    l10n.voiceInputStarting,
                                  ComposerVoiceInputState.stopping =>
                                    l10n.voiceInputFinishing,
                                  _ => l10n.voiceInputListening,
                                },
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const Key('popi-voice-cancel'),
                              tooltip: l10n.voiceInputCancel,
                              onPressed: () =>
                                  _voiceInput.cancel(discard: true),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.selectedAssets.isNotEmpty) ...[
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        key: const Key('popi-selected-assets'),
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.selectedAssets.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final work = widget.selectedAssets[index];
                          final onPreview = widget.onPreviewAsset == null
                              ? null
                              : () => widget.onPreviewAsset!(index);
                          final thumbnail =
                              widget.selectedAssetThumbnailBuilder?.call(
                                context,
                                index,
                              ) ??
                              LibraryWorkThumbnail(work: work);
                          return SizedBox.square(
                            key: ValueKey('popi-selected-asset-${work.id}'),
                            dimension: 92,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (onPreview == null)
                                  thumbnail
                                else
                                  Positioned.fill(
                                    child: Tooltip(
                                      message: l10n.previewAttachment,
                                      child: Semantics(
                                        button: true,
                                        label: l10n.previewAttachment,
                                        onTap: onPreview,
                                        child: FocusableActionDetector(
                                          key: ValueKey(
                                            'popi-preview-selected-asset-${work.id}',
                                          ),
                                          shortcuts: const {
                                            SingleActivator(
                                              LogicalKeyboardKey.enter,
                                            ): ActivateIntent(),
                                            SingleActivator(
                                              LogicalKeyboardKey.space,
                                            ): ActivateIntent(),
                                          },
                                          actions: {
                                            ActivateIntent:
                                                CallbackAction<ActivateIntent>(
                                                  onInvoke: (_) {
                                                    onPreview();
                                                    return null;
                                                  },
                                                ),
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onDoubleTap: onPreview,
                                            child: thumbnail,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    key: ValueKey(
                                      'popi-remove-selected-asset-${work.id}',
                                    ),
                                    tooltip: l10n.removeAsset,
                                    onPressed: widget.sending
                                        ? null
                                        : () =>
                                              widget.onRemoveAsset?.call(index),
                                    style: IconButton.styleFrom(
                                      backgroundColor: colorScheme.surface,
                                    ),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.selectedRoles.isNotEmpty) ...[
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        key: const Key('popi-selected-roles'),
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.selectedRoles.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final role = widget.selectedRoles[index];
                          return Container(
                            key: ValueKey('popi-selected-role-${role.id}'),
                            padding: const EdgeInsets.only(left: 6),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width - 40,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RoleGuideAvatar(role: role, size: 32),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    role.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey(
                                    'popi-remove-selected-role-${role.id}',
                                  ),
                                  tooltip: l10n.removeRole,
                                  onPressed: widget.sending
                                      ? null
                                      : () => widget.onRemoveRole?.call(index),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller.textController,
                        builder: (context, value, _) {
                          final text = widget.controller.markdown;
                          final inputLayout = _measureInput(
                            value.text,
                            constraints.maxWidth - 20,
                            Directionality.of(context),
                          );
                          return TweenAnimationBuilder<double>(
                            tween: Tween(end: inputLayout.height),
                            duration: _composerAnimationController.isCompleted
                                ? const Duration(milliseconds: 180)
                                : Duration.zero,
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedInputHeight, _) {
                              final expandedHeight =
                                  (hasImages
                                      ? 136.0
                                      : widget.conversationMode
                                      ? 78.0
                                      : 70.0) +
                                  animatedInputHeight;
                              final contentHeight = _isExpanded
                                  ? expandedHeight
                                  : 60.0;
                              final content = _ComposerContent(
                                isExpanded: _isExpanded,
                                hasText:
                                    text.isNotEmpty ||
                                    widget.selectedRoles.isNotEmpty ||
                                    widget.selectedAssets.isNotEmpty,
                                sending: widget.sending,
                                running: widget.running,
                                onStop: widget.onStop,
                                onVoiceInput: _toggleVoiceInput,
                                voiceActive: _voiceInput.active,
                                voicePending:
                                    _voiceInput.state ==
                                        ComposerVoiceInputState.starting ||
                                    _voiceInput.state ==
                                        ComposerVoiceInputState.stopping,
                                images: widget.selectedImages,
                                expandedInputHeight: animatedInputHeight,
                                onExpand: inputLayout.overflows
                                    ? _openExpandedEditor
                                    : null,
                                input: _buildInput(
                                  colorScheme,
                                  placeholderFontSize:
                                      widget.sessionLayout && !_isExpanded
                                      ? 14
                                      : widget.conversationMode
                                      ? 18
                                      : 14,
                                ),
                                colorScheme: colorScheme,
                                onAttachment: () {
                                  _voiceInput.cancel();
                                  widget.onAttachment();
                                },
                                onRemoveImage: widget.onRemoveImage,
                                onRetryImage: widget.onRetryImage,
                                attachmentsReady: widget.attachmentsReady,
                                onSubmitted: () => _submit(text),
                                onModelParametersRequested:
                                    widget.onModelParametersRequested,
                                modelParametersDescription:
                                    widget.modelParametersDescription,
                                castRoles: widget.castRoles,
                                onCastRequested: widget.onCastRequested,
                                castEnabled: widget.castEnabled,
                              );
                              return AnimatedBuilder(
                                animation: _composerAnimationController,
                                builder: (context, _) {
                                  final progress = Curves.easeInOutCubic
                                      .transform(
                                        _composerAnimationController.value,
                                      );
                                  final height =
                                      60 + (expandedHeight - 60) * progress;
                                  final radius =
                                      AppRadii.pill +
                                      (AppRadii.card - AppRadii.pill) *
                                          progress;
                                  final borderRadius = BorderRadius.circular(
                                    radius,
                                  );
                                  // Selection handles and the editing toolbar belong to
                                  // the text field's tap group even outside this frame.
                                  return TextFieldTapRegion(
                                    onTapOutside: (_) => _dismissEditor(),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: _focusInput,
                                      child: Container(
                                        key: const Key('popi-message-composer'),
                                        width: double.infinity,
                                        height: height,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? colorScheme.surfaceContainerHigh
                                              : AppColors.surface,
                                          border: isDark
                                              ? Border.all(
                                                  color: colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: .45),
                                                )
                                              : null,
                                          borderRadius: borderRadius,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: isDark ? 0.2 : 0.025,
                                              ),
                                              blurRadius: isDark ? 14 : 12,
                                              offset: Offset(0, isDark ? 0 : 4),
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
                                              padding: _isExpanded
                                                  ? const EdgeInsets.all(10)
                                                  : const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                    ),
                                              child: RepaintBoundary(
                                                child: content,
                                              ),
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
                      );
                    },
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
    bool expandedEditor = false,
    bool? readOnly,
    bool? running,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isRunning = running ?? widget.running;
    final placeholderStyle = TextStyle(
      color: Theme.of(context).brightness == Brightness.light
          ? AppColors.textTertiary
          : colorScheme.onSurfaceVariant,
      fontSize: placeholderFontSize,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isRunning ? _showRunningToast : null,
      child: AbsorbPointer(
        absorbing: isRunning,
        child: ExtendedTextField(
          key: Key(
            expandedEditor
                ? 'popi-expanded-message-input'
                : 'popi-message-input',
          ),
          focusNode: expandedEditor ? null : _focusNode,
          autofocus: expandedEditor,
          onTapOutside: (_) => widget.controller.dismissKeyboard(),
          controller: widget.controller.textController,
          onChanged: _handleUserTextChanged,
          scrollController: expandedEditor ? null : _inputScroll,
          enabled: !isRunning,
          readOnly:
              isRunning || _voiceInput.active || (readOnly ?? widget.sending),
          specialTextSpanBuilder: widget.controller.specialTextSpanBuilder,
          minLines: expandedEditor
              ? null
              : _isExpanded && !widget.conversationMode
              ? 2
              : 1,
          maxLines: expandedEditor ? null : 3,
          expands: expandedEditor,
          cursorColor: colorScheme.primary,
          textAlignVertical: expandedEditor || _isExpanded
              ? TextAlignVertical.top
              : TextAlignVertical.center,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: expandedEditor || (_isExpanded && widget.conversationMode)
                ? 18
                : placeholderFontSize,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            fillColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: widget.placeholderText ?? l10n.composerPlaceholder,
            hintStyle: placeholderStyle,
          ),
        ),
      ),
    );
  }

  ({double height, bool overflows}) _measureInput(
    String rawText,
    double maxWidth,
    TextDirection textDirection,
  ) {
    final tokenizedText = rawText.replaceAll(
      RegExp(r'\[popi-image:\d+\]'),
      '\uFFFC',
    );
    final displayText = tokenizedText.isEmpty ? ' ' : tokenizedText;
    final painter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          fontSize: widget.conversationMode ? 18 : 14,
          height: 1.5,
        ),
      ),
      maxLines: 3,
      textDirection: textDirection,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final lines = painter.computeLineMetrics().length.clamp(
      widget.conversationMode ? 1 : 2,
      3,
    );
    final overflows = painter.didExceedMaxLines;
    painter.dispose();
    // Match the editor's scaled line height so accessibility fonts are not clipped.
    return (
      height:
          lines *
          MediaQuery.textScalerOf(
            context,
          ).scale(widget.conversationMode ? 18 : 14) *
          1.5,
      overflows: overflows,
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({
    required this.image,
    required this.index,
    required this.size,
    required this.onRemove,
    this.onRetry,
  });

  final PopiComposerImage image;
  final int index;
  final double size;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

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
            if (image.state != ComposerImageUploadState.selected)
              Positioned.fill(
                child: _ImageUploadStatus(
                  image: image,
                  index: index,
                  compact: isCompact,
                  onRetry: onRetry,
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

class _ImageUploadStatus extends StatelessWidget {
  const _ImageUploadStatus({
    required this.image,
    required this.index,
    required this.compact,
    this.onRetry,
  });

  final PopiComposerImage image;
  final int index;
  final bool compact;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    if (image.state == ComposerImageUploadState.ready) {
      return IgnorePointer(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Tooltip(
            message: l10n.imageUploadComplete,
            child: Container(
              key: Key('popi-image-upload-ready-$index'),
              margin: const EdgeInsets.all(2),
              width: compact ? 12 : 16,
              height: compact ? 12 : 16,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: compact ? 10 : 13,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      );
    }
    final failed = image.state == ComposerImageUploadState.failed;
    final processing = image.state == ComposerImageUploadState.processing;
    final percent = (image.progress * 100).floor();
    final label = failed
        ? l10n.imageUploadFailed
        : processing
        ? l10n.imageUploadProcessing
        : l10n.imageUploadProgress(percent);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .5),
        child: Tooltip(
          message: failed ? '$label · ${l10n.retry}' : label,
          child: Stack(
            children: [
              Align(
                alignment: compact
                    ? Alignment.center
                    : const Alignment(-.8, -.15),
                child: failed
                    ? SizedBox.square(
                        dimension: compact ? 26 : 24,
                        child: IconButton(
                          key: Key('popi-image-upload-retry-$index'),
                          tooltip: l10n.retry,
                          padding: EdgeInsets.zero,
                          onPressed: onRetry,
                          icon: Icon(
                            Icons.refresh_rounded,
                            size: compact ? 18 : 22,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : SizedBox.square(
                        dimension: compact ? 18 : 20,
                        child: CircularProgressIndicator(
                          key: Key('popi-image-upload-progress-$index'),
                          value: processing || image.progress == 0
                              ? null
                              : image.progress,
                          strokeWidth: 2,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                          semanticsLabel: label,
                        ),
                      ),
              ),
              if (!compact)
                Positioned(
                  left: 2,
                  right: 2,
                  bottom: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      failed || processing ? label : '$percent%',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
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
    required this.expandedInputHeight,
    required this.onExpand,
    required this.input,
    required this.colorScheme,
    required this.onAttachment,
    required this.onRemoveImage,
    required this.onRetryImage,
    required this.attachmentsReady,
    required this.onSubmitted,
    required this.onModelParametersRequested,
    required this.modelParametersDescription,
    required this.sending,
    required this.running,
    required this.onStop,
    required this.onVoiceInput,
    required this.voiceActive,
    required this.voicePending,
    required this.castRoles,
    required this.onCastRequested,
    required this.castEnabled,
  });

  final bool isExpanded;
  final bool hasText;
  final List<PopiComposerImage> images;
  final double expandedInputHeight;
  final VoidCallback? onExpand;
  final Widget input;
  final ColorScheme colorScheme;
  final VoidCallback onAttachment;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int>? onRetryImage;
  final bool attachmentsReady;
  final VoidCallback onSubmitted;
  final VoidCallback? onModelParametersRequested;
  final String modelParametersDescription;
  final bool sending;
  final bool running;
  final VoidCallback? onStop;
  final VoidCallback? onVoiceInput;
  final bool voiceActive;
  final bool voicePending;
  final List<LibraryRole>? castRoles;
  final VoidCallback? onCastRequested;
  final bool castEnabled;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);
    const curve = Curves.easeOutCubic;
    final hasImages = images.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showSend = hasText || hasImages || running || sending;
    final showVoice = onVoiceInput != null && !running && !sending;
    final showAction = showSend || showVoice;
    final showCast = castRoles != null;
    final compactTrailingWidth =
        (showSend ? 48.0 : 0.0) + (showVoice ? 48.0 : 0.0);
    final compactImageStripWidth = images.isEmpty
        ? 0.0
        : images.length * 28.0 + (images.length - 1) * 6.0;
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
              separatorBuilder: (_, __) => SizedBox(width: isExpanded ? 8 : 6),
              itemBuilder: (context, index) => _SelectedImagePreview(
                image: images[index],
                index: index,
                size: isExpanded ? 58 : 28,
                onRemove: () => onRemoveImage(index),
                onRetry: onRetryImage == null
                    ? null
                    : () => onRetryImage!(index),
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
                          right: onExpand != null ? 36 : 0,
                        )
                      : EdgeInsets.only(
                          left: 58 + compactImageStripWidth,
                          right: compactTrailingWidth,
                        )
                : isExpanded
                ? EdgeInsets.only(bottom: 50, right: onExpand != null ? 36 : 0)
                : EdgeInsets.only(left: 50, right: compactTrailingWidth),
            child: Align(
              alignment: isExpanded ? Alignment.topLeft : Alignment.centerLeft,
              child: SizedBox(
                width: double.infinity,
                height: isExpanded ? expandedInputHeight : null,
                child: input,
              ),
            ),
          ),
        ),
        if (isExpanded && onExpand != null)
          Positioned(
            top: hasImages ? 66 : 0,
            right: 0,
            child: SizedBox.square(
              dimension: 32,
              child: IconButton(
                key: const Key('popi-expand-input'),
                tooltip: AppLocalizations.of(context)!.composerExpandInput,
                onPressed: sending ? null : onExpand,
                padding: const EdgeInsets.all(5),
                icon: const AppSvgIcon.asset('chat_expand_input', size: 22),
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
        if (onModelParametersRequested != null || showCast)
          Positioned(
            left: isExpanded ? 50 : null,
            right: compactTrailingWidth,
            width: isExpanded ? null : 132,
            bottom: isExpanded ? 0 : 10,
            height: 40,
            child: IgnorePointer(
              ignoring: !isExpanded,
              child: AnimatedOpacity(
                duration: duration,
                curve: curve,
                opacity: isExpanded ? 1 : 0,
                child: SingleChildScrollView(
                  key: const Key('popi-composer-tools'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showCast)
                        _CastButton(
                          roles: castRoles!,
                          onPressed: castEnabled && !sending && !running
                              ? onCastRequested
                              : null,
                        ),
                      if (isExpanded && onModelParametersRequested != null) ...[
                        if (showCast) const SizedBox(width: 4),
                        _ModelParametersButton(
                          description: modelParametersDescription,
                          onPressed: onModelParametersRequested!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 0,
          bottom: isExpanded ? 0 : 10,
          child: IgnorePointer(
            ignoring: !showAction,
            child: AnimatedOpacity(
              duration: duration,
              curve: curve,
              opacity: showAction ? 1 : 0,
              child: AnimatedSize(
                duration: duration,
                curve: curve,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showVoice)
                      SizedBox.square(
                        dimension: 40,
                        child: IconButton(
                          key: const Key('popi-voice-input'),
                          tooltip: voiceActive
                              ? AppLocalizations.of(context)!.voiceInputStop
                              : AppLocalizations.of(context)!.voiceInput,
                          onPressed: voicePending ? null : onVoiceInput,
                          style: IconButton.styleFrom(
                            backgroundColor: voiceActive
                                ? colorScheme.primaryContainer
                                : isDark
                                ? colorScheme.surfaceContainerHighest
                                      .withValues(alpha: .35)
                                : AppColors.surface,
                            shape: CircleBorder(
                              side: BorderSide(
                                color: voiceActive
                                    ? colorScheme.primary.withValues(alpha: .3)
                                    : isDark
                                    ? colorScheme.outlineVariant
                                    : const Color(0xFFE6E6E6),
                                width: 1,
                              ),
                            ),
                            foregroundColor: voiceActive
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                          icon: voicePending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const AppSvgIcon.asset('demo_mic', size: 22),
                        ),
                      ),
                    if (showVoice && showSend) const SizedBox(width: 8),
                    if (showSend)
                      _SendButton(
                        onPressed: sending || voiceActive
                            ? null
                            : running
                            ? onStop
                            : attachmentsReady
                            ? onSubmitted
                            : null,
                        sending: sending,
                        running: running,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CastButton extends StatelessWidget {
  const _CastButton({required this.roles, required this.onPressed});

  final List<LibraryRole> roles;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = roles.isEmpty
        ? l10n.chatCastUnmatched
        : roles.length == 1
        ? roles.single.title
        : l10n.chatCastMultiple(roles.length);
    return Tooltip(
      message: '${l10n.chatCastRole}: $label',
      child: TextButton(
        key: const Key('popi-composer-cast'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: AppColors.brand.withValues(alpha: .05),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (roles.isEmpty)
              SizedBox.square(
                dimension: 24,
                child: Center(
                  child: Transform.flip(
                    flipY: true,
                    child: const AppSvgIcon.asset(
                      'chat_cast_unmatched',
                      size: 19,
                    ),
                  ),
                ),
              ),
            if (roles.isNotEmpty)
              SizedBox(
                width: 24 + (roles.length.clamp(1, 3) - 1) * 12,
                height: 24,
                child: Stack(
                  children: [
                    for (final (index, role) in roles.take(3).indexed)
                      Positioned(
                        left: index * 12,
                        top: 0,
                        child: RoleGuideAvatar(role: role, size: 24),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelParametersButton extends StatelessWidget {
  const _ModelParametersButton({
    required this.description,
    required this.onPressed,
  });

  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: description,
      child: TextButton(
        key: const Key('popi-model-parameters'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.brand.withValues(alpha: .05),
          foregroundColor: colors.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 24,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: AppSvgIcon.asset(
                    'role_guide_model',
                    size: 19.2,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              AppLocalizations.of(context)!.roleModelParameters,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: l10n.addAttachment,
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: .05),
          shape: const CircleBorder(),
        ),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: SvgPicture.asset(
          'assets/icons/home_composer_add.svg',
          width: 16,
          height: 16,
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.onPressed,
    this.sending = false,
    this.running = false,
    this.icon,
  });

  final VoidCallback? onPressed;
  final bool sending;
  final bool running;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        key: const Key('popi-send-button'),
        tooltip: sending
            ? AppLocalizations.of(context)!.chatSending
            : running
            ? AppLocalizations.of(context)!.chatStop
            : AppLocalizations.of(context)!.sendMessage,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF6F47F5),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
        onPressed: onPressed,
        icon: sending
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : running
            ? const Icon(Icons.stop_rounded, size: 24)
            : icon != null
            ? Icon(icon, size: 24)
            : AppSvgIcon.asset(
                'home_composer_send',
                size: 25,
                color: Colors.white,
                semanticsLabel: AppLocalizations.of(context)!.sendMessage,
              ),
      ),
    );
  }
}
