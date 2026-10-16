import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/navigation.dart';
import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/session_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../attachments/presentation/attachment_picker_sheet.dart';
import '../../assets/domain/library_role.dart';
import '../../assets/domain/library_work.dart';
import '../../role_guide/domain/role_guide_draft.dart';
import '../../role_guide/domain/home_creation.dart';
import '../../role_guide/data/media_preferences_repository.dart';
import '../../role_guide/presentation/widgets/home_generation_config_sheet.dart';
import '../../role_guide/presentation/widgets/role_generation_sheet.dart';
import '../domain/conversation_session.dart';
import 'widgets/popi_message_composer.dart';
import 'conversation_controller.dart';
import 'composer_image_upload_controller.dart';
import 'widgets/conversation_timeline.dart';
import 'widgets/session_welcome.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';

/// Creation session with a prompt composer and attachment selection.
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({
    this.pickImages,
    this.initialPrompt,
    this.sessionId,
    this.accountId,
    super.key,
  });

  final Future<List<XFile>> Function()? pickImages;
  final String? initialPrompt;
  final String? sessionId;
  final String? accountId;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _messageController = PopiMessageComposerController();
  bool _drawerOpen = false;
  double _composerHeight = 0;
  final _imageUploads = ComposerImageUploadController();
  List<PopiComposerImage> get _selectedImages => _imageUploads.images;
  final List<LibraryRole> _selectedRoles = [];
  final List<LibraryWork> _selectedAssets = [];
  bool _mentionMode = false;
  int _composerRevision = 0;
  RoleGenerationSettings _generationSettings = const RoleGenerationSettings();
  bool _generationSheetOpen = false;
  String? _mediaPreferenceDescription;
  String? _activeSessionId;
  String? _accountId;
  Map<String, HomeConfig> _draftMediaPreferences = const {};
  ConversationController? _conversation;

  static const _maxImageCount = 5;
  static const _maxImageBytes = 6 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _imageUploads.addListener(_onImageUploadsChanged);
    _activeSessionId = widget.sessionId;
    _accountId = widget.accountId;
    _bindConversation();
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectPrompt(widget.initialPrompt!);
      });
    }
  }

  @override
  void didUpdateWidget(SessionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.accountId != widget.accountId) {
      // 新建会话写回路由时沿用正在发送的控制器，避免取消首条消息。
      if (widget.sessionId != null && widget.sessionId == _activeSessionId) {
        return;
      }
      _activeSessionId = widget.sessionId;
      _accountId = widget.accountId;
      _draftMediaPreferences = const {};
      _mediaPreferenceDescription = null;
      _bindConversation();
      _resetComposer();
    }
  }

  void _resetComposer() {
    _composerRevision++;
    _imageUploads.clear();
    _selectedRoles.clear();
    _selectedAssets.clear();
    _mentionMode = false;
    _messageController.setText('');
    _messageController.dismissKeyboard();
  }

  @override
  void dispose() {
    _imageUploads
      ..removeListener(_onImageUploadsChanged)
      ..dispose();
    _conversation?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onImageUploadsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (previous, next) {
      if (previous == next) return;
      setState(() {
        _activeSessionId = null;
        _accountId = null;
        _draftMediaPreferences = const {};
        _mediaPreferenceDescription = null;
        _resetComposer();
        _bindConversation();
      });
    });
    final l10n = AppLocalizations.of(context)!;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final composerBottomPadding = math
        .max(safeArea.bottom - keyboardHeight, 20)
        .toDouble();
    final fallbackComposerHeight = 8 + 60 + 10 + 14 + composerBottomPadding;
    final composerHeight = _composerHeight > 0
        ? _composerHeight
        : fallbackComposerHeight;
    final composerInset = composerHeight + keyboardHeight;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoggedIn = ref.watch(userProvider) != null;
    final showWelcome =
        _activeSessionId == null ||
        (_conversation?.snapshot?.messages.isEmpty == true &&
            !(_conversation?.running ?? false) &&
            !(_conversation?.pending ?? false));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : const Color(0xFFF5F4FA),
      ),
      child: GestureDetector(
        key: const Key('popi-home-dismiss-keyboard'),
        behavior: HitTestBehavior.translucent,
        onTap: _messageController.dismissKeyboard,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          drawer: PopiNavigationDrawer(
            onOpenConversation: _selectConversation,
            onNewConversation: _startNewConversation,
          ),
          drawerScrimColor: const Color(0x33333333),
          onDrawerChanged: (isOpened) {
            if (_drawerOpen != isOpened) {
              setState(() => _drawerOpen = isOpened);
            }
          },
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(safeArea.top + 56),
            child: Padding(
              padding: EdgeInsets.only(top: safeArea.top),
              child: SizedBox(
                key: const Key('popi-home-app-bar'),
                height: 56,
                child: _blurBehindDrawer(
                  AppBar(
                    primary: false,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: 56,
                    leadingWidth: 80,
                    leading: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: SizedBox.square(
                          dimension: 40,
                          child: IconButton(
                            key: const Key('popi-open-navigation'),
                            tooltip: l10n.openNavigation,
                            padding: const EdgeInsets.all(5),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            icon: AppSvgIcon.asset(
                              'common_navigation_menu',
                              size: 30,
                              color: colorScheme.onSurface,
                              semanticsLabel: l10n.openNavigation,
                            ),
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: SizedBox.square(
                          dimension: 40,
                          child: IconButton(
                            key: const Key('session-new-conversation'),
                            tooltip: l10n.newConversation,
                            padding: const EdgeInsets.all(4),
                            onPressed: _startNewConversation,
                            icon: SizedBox(
                              width: 30,
                              height: 32,
                              child: AppSvgIcon.asset(
                                'session_new_conversation',
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: _blurBehindDrawer(
            Stack(
              fit: StackFit.expand,
              children: [
                if (!showWelcome && _conversation != null)
                  Positioned.fill(
                    bottom: composerInset,
                    child: ConversationTimeline(
                      key: ValueKey(
                        '${_conversation!.userId}:$_activeSessionId',
                      ),
                      controller: _conversation!,
                      onRevise: (content) =>
                          _selectPrompt(l10n.chatRevisePrompt(content.title)),
                    ),
                  )
                else
                  Positioned.fill(
                    bottom: composerInset,
                    child: SessionWelcome(keyboardVisible: keyboardHeight > 0),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: composerInset - 1,
                  height: 32,
                  child: IgnorePointer(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: ClipRect(
                        child: BackdropFilter(
                          key: const Key('popi-composer-region-feather'),
                          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  colorScheme.surface.withValues(
                                    alpha: isDark ? .05 : .02,
                                  ),
                                  colorScheme.surface.withValues(
                                    alpha: isDark ? .14 : .06,
                                  ),
                                ],
                                stops: const [0, .55, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  // Keep the keyboard's occluded area outside the blur layer.
                  bottom: keyboardHeight,
                  child: ClipRect(
                    child: BackdropFilter(
                      key: const Key('popi-composer-region-blur'),
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: ColoredBox(
                        key: const Key('popi-composer-region-surface'),
                        color: colorScheme.surface.withValues(
                          alpha: isDark ? .14 : .06,
                        ),
                        child: Center(
                          heightFactor: 1,
                          child: PopiMessageComposer(
                            conversationMode: true,
                            sessionLayout: true,
                            controller: _messageController,
                            selectedImages: _selectedImages,
                            selectedRoles: _selectedRoles,
                            onRemoveRole: _removeSelectedRole,
                            selectedAssets: _selectedAssets,
                            onRemoveAsset: _removeSelectedAsset,
                            onAttachment: _showAttachmentSheet,
                            onRemoveImage: _removeSelectedImage,
                            onRetryImage: _retryImageUpload,
                            attachmentsReady:
                                !isLoggedIn || _imageUploads.ready,
                            onHeightChanged: _handleComposerHeightChanged,
                            onSubmitted: _openConversation,
                            sending:
                                (_conversation?.pending ?? false) ||
                                (_conversation?.loading ?? false),
                            running: _conversation?.running ?? false,
                            onStop: () => _conversation?.stop(),
                            onMentionRequested: _showMentionSheet,
                            onModelParametersRequested: _showModelParameters,
                            modelParametersDescription:
                                _mediaPreferenceDescription ??
                                (_conversation != null
                                    ? l10n.roleModelParameters
                                    : [
                                        _generationSettings.model.label,
                                        '${l10n.roleVideoPreference}: ${_generationSettings.videoResolution}P / ${_generationSettings.videoRatio.label}',
                                        '${l10n.roleImagePreference}: ${_generationSettings.imageResolution}P / ${_generationSettings.imageRatio.label}',
                                        '${l10n.roleDuration}: ${_generationSettings.duration == null ? l10n.roleDurationAutomatic : l10n.roleDurationSeconds(_generationSettings.duration.toString())}',
                                      ].join('\n')),
                          ),
                        ),
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

  Widget _blurBehindDrawer(Widget child) {
    if (!_drawerOpen) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
      child: child,
    );
  }

  void _selectConversation(ConversationSession session) {
    setState(() {
      _activeSessionId = session.id;
      _accountId = null;
      _draftMediaPreferences = const {};
      _mediaPreferenceDescription = null;
      _bindConversation();
      _resetComposer();
    });
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    AppNavigation.replaceRoot(
      router,
      Uri(
        path: '/session',
        queryParameters: {'sessionId': session.id},
      ).toString(),
    );
  }

  void _startNewConversation() {
    if (ref.read(userProvider) == null) {
      GoRouter.maybeOf(context)?.push('/login');
      return;
    }
    setState(() {
      _activeSessionId = null;
      _accountId = null;
      _draftMediaPreferences = const {};
      _mediaPreferenceDescription = null;
      _resetComposer();
      _bindConversation();
    });
    final router = GoRouter.maybeOf(context);
    if (router != null) AppNavigation.replaceRoot(router, '/session');
  }

  void _bindConversation() {
    _conversation?.dispose();
    final userId = ref.read(userProvider)?.id;
    _conversation = userId == null
        ? null
        : ConversationController(
            ref.read(sessionRepositoryProvider),
            userId,
            accountId: _accountId,
            mediaPreferencesRepository: MediaPreferencesRepository(
              NetworkApi(ref.read(dioProvider)),
            ),
            onError: (error) {
              if (!mounted || ref.read(userProvider)?.id != userId) return;
              AppToast.error(
                context,
                conversationErrorText(error, AppLocalizations.of(context)!),
              );
            },
            onSessionChanged: (session) {
              if (!mounted || ref.read(userProvider)?.id != userId) return;
              final changed = _activeSessionId != session.id;
              _activeSessionId = session.id;
              ref.read(sessionsProvider.notifier).upsert(session);
              // 先保存新会话的路由，首条消息超时后仍能回到同一会话重试。
              if (changed) {
                GoRouter.maybeOf(context)?.replace(
                  Uri(
                    path: '/session',
                    queryParameters: {'sessionId': session.id},
                  ).toString(),
                );
              }
            },
          );
    _conversation?.addListener(() {
      if (mounted) setState(() {});
    });
    _conversation?.open(_activeSessionId);
  }

  Future<void> _openConversation(String value) async {
    if (value.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedAssets.isEmpty &&
        _selectedRoles.isEmpty) {
      return;
    }
    if (ref.read(userProvider) == null) {
      GoRouter.maybeOf(context)?.push('/login');
      return;
    }
    if (!_imageUploads.ready) return;
    final conversation = _conversation;
    if (conversation == null ||
        conversation.pending ||
        conversation.running ||
        _generationSheetOpen) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final success = await conversation.send(
      value.trim(),
      const [],
      l10n.newSessionTitle,
      _selectedImages.isEmpty &&
              _selectedAssets.isEmpty &&
              _selectedRoles.isNotEmpty
          ? l10n.chatRolePrompt
          : l10n.chatMediaPrompt,
      roleIds: _selectedRoles.map((role) => role.id).toList(),
      assets: List.of(_selectedAssets),
      uploadedMediaIds: [for (final image in _selectedImages) image.mediaId!],
      mediaPreferences: _draftMediaPreferences,
    );
    if (!mounted ||
        !identical(conversation, _conversation) ||
        conversation.sessionId != _activeSessionId) {
      return;
    }
    if (success) {
      _draftMediaPreferences = const {};
      setState(_resetComposer);
      GoRouter.maybeOf(context)?.replace(
        Uri(
          path: '/session',
          queryParameters: {'sessionId': conversation.sessionId!},
        ).toString(),
      );
    }
  }

  Future<void> _showModelParameters() async {
    if (_generationSheetOpen) return;
    _generationSheetOpen = true;
    _messageController.dismissKeyboard();
    try {
      final conversation = _conversation;
      if (conversation != null) {
        final sessionId = _activeSessionId;
        final result = await AppSheet.show<HomeGenerationConfiguration>(
          context: context,
          isScrollControlled: true,
          showDragHandle: false,
          backgroundColor: Colors.transparent,
          builder: (_) => HomeGenerationConfigSheet(
            repository: MediaPreferencesRepository(
              NetworkApi(ref.read(dioProvider)),
            ),
            sessionId: sessionId,
            savedPreferences: _draftMediaPreferences,
            forGeneration: false,
          ),
        );
        if (mounted &&
            result != null &&
            identical(conversation, _conversation) &&
            _activeSessionId == sessionId) {
          setState(() {
            _mediaPreferenceDescription = result.description;
            _draftMediaPreferences = sessionId == null
                ? result.preferences
                : const {};
          });
          if (sessionId != null) conversation.mediaPreferencesChanged();
        }
        return;
      }
      final settings = await AppSheet.show<RoleGenerationSettings>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            RoleGenerationSheet(initialSettings: _generationSettings),
      );
      if (settings != null && mounted) {
        setState(() => _generationSettings = settings);
      }
    } finally {
      _generationSheetOpen = false;
    }
  }

  Future<void> _selectPrompt(String prompt) async {
    await _messageController.setText(prompt);
    if (mounted) setState(() {});
  }

  void _handleComposerHeightChanged(double height) {
    if ((height - _composerHeight).abs() < .5 || !mounted) return;
    setState(() => _composerHeight = height);
  }

  Future<void> _addImages(List<XFile> images) async {
    final revision = _composerRevision;
    if (_conversation?.pending ?? false) return;
    final remaining =
        _maxImageCount - _selectedImages.length - _selectedAssets.length;
    if (remaining <= 0) {
      AppToast.info(context, AppLocalizations.of(context)!.maximumImageCount);
      return;
    }

    try {
      if (images.isEmpty) return;

      final selected = <PopiComposerImage>[];
      var hasOversizedImage = false;
      for (final image in images) {
        if (selected.length >= remaining) break;
        final bytes = await image.readAsBytes();
        if (bytes.lengthInBytes > _maxImageBytes) {
          hasOversizedImage = true;
          continue;
        }
        final isDuplicate = [..._selectedImages, ...selected].any(
          (selectedImage) =>
              selectedImage.name == image.name &&
              listEquals(selectedImage.bytes, bytes),
        );
        if (isDuplicate) continue;
        selected.add(PopiComposerImage(name: image.name, bytes: bytes));
      }
      if (!mounted || revision != _composerRevision) return;
      if (selected.isNotEmpty) {
        _imageUploads.add(selected);
        final userId = ref.read(userProvider)?.id;
        if (userId != null) {
          final repository = ref.read(sessionRepositoryProvider);
          for (final image in selected) {
            unawaited(_imageUploads.upload(image, repository, userId));
          }
        }
        if (_mentionMode) {
          _mentionMode = false;
          final markdown = _messageController.markdown;
          if (markdown.endsWith('@')) {
            await _messageController.setText(
              markdown.substring(0, markdown.length - 1),
            );
          }
          await _messageController.insertImage(selected.first.bytes);
          if (!mounted) return;
        }
      }
      if (hasOversizedImage) {
        AppToast.error(context, AppLocalizations.of(context)!.imageTooLarge);
      }
      if (images.length > remaining) {
        AppToast.info(context, AppLocalizations.of(context)!.maximumImageCount);
      }
    } catch (_) {
      if (mounted) {
        AppToast.info(context, AppLocalizations.of(context)!.imageReadFailed);
      }
    }
  }

  void _removeSelectedImage(int index) {
    if (_conversation?.pending ?? false) return;
    if (index < 0 || index >= _selectedImages.length) return;
    _imageUploads.remove(index);
  }

  void _retryImageUpload(int index) {
    if (_conversation?.pending ?? false) return;
    final userId = ref.read(userProvider)?.id;
    if (userId == null) {
      GoRouter.maybeOf(context)?.push('/login');
      return;
    }
    unawaited(
      _imageUploads.upload(
        _selectedImages[index],
        ref.read(sessionRepositoryProvider),
        userId,
      ),
    );
  }

  Future<void> _showAttachmentSheet() async {
    if (_conversation?.pending ?? false) return;
    final revision = _composerRevision;
    final remaining =
        _maxImageCount - _selectedImages.length - _selectedAssets.length;
    _messageController.dismissKeyboard();
    final result = await AttachmentPickerSheet.show(
      context: context,
      limit: remaining,
      pickImages: widget.pickImages,
      selectedRoles: List.of(_selectedRoles),
      selectedAssets: List.of(_selectedAssets),
    );
    if (!mounted || revision != _composerRevision || result == null) return;
    if (result.roles != null) {
      setState(() {
        _selectedRoles
          ..clear()
          ..addAll(result.roles!);
      });
    }
    if (result.assets != null) {
      setState(() {
        _selectedAssets
          ..clear()
          ..addAll(result.assets!);
      });
    }
    if (result.images.isNotEmpty) await _addImages(result.images);
  }

  void _removeSelectedRole(int index) {
    if (_conversation?.pending ?? false) return;
    if (index < 0 || index >= _selectedRoles.length) return;
    setState(() => _selectedRoles.removeAt(index));
  }

  void _removeSelectedAsset(int index) {
    if (_conversation?.pending ?? false) return;
    if (index < 0 || index >= _selectedAssets.length) return;
    setState(() => _selectedAssets.removeAt(index));
  }

  void _showMentionSheet() {
    if (_selectedImages.isEmpty) return;
    _mentionMode = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppSheet.show<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final image = _selectedImages[index];
                  return InkWell(
                    key: Key('popi-mention-image-$index'),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _insertMentionImage(image);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: Image.memory(
                        image.bytes,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _insertMentionImage(PopiComposerImage image) async {
    _mentionMode = false;
    final markdown = _messageController.markdown;
    if (markdown.endsWith('@')) {
      await _messageController.setText(
        markdown.substring(0, markdown.length - 1),
      );
    }
    await _messageController.insertImage(image.bytes);
  }
}
