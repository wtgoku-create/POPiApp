import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/navigation.dart';
import '../../../app/theme.dart';
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
import '../../role_guide/presentation/widgets/role_generation_sheet.dart';
import 'widgets/popi_message_composer.dart';
import 'conversation_controller.dart';
import 'widgets/conversation_timeline.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../../../shared/widgets/popi_membership_entry.dart';
import '../../../shared/widgets/popi_app_bar_actions.dart';

/// Creation session with a prompt composer and attachment selection.
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({
    this.pickImages,
    this.initialPrompt,
    this.sessionId,
    super.key,
  });

  final Future<List<XFile>> Function()? pickImages;
  final String? initialPrompt;
  final String? sessionId;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _messageController = PopiMessageComposerController();
  final _bodyScrollController = ScrollController();
  bool _drawerOpen = false;
  double _composerHeight = 0;
  double _keyboardHeight = 0;
  double _bodyOffsetBeforeKeyboard = 0;
  final List<PopiComposerImage> _selectedImages = [];
  final List<LibraryRole> _selectedRoles = [];
  final List<LibraryWork> _selectedAssets = [];
  bool _mentionMode = false;
  RoleGenerationSettings _generationSettings = const RoleGenerationSettings();
  bool _generationSheetOpen = false;
  String? _activeSessionId;
  ConversationController? _conversation;

  static const _maxImageCount = 5;
  static const _maxImageBytes = 6 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _activeSessionId = widget.sessionId;
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
    if (oldWidget.sessionId != widget.sessionId) {
      // 新建会话写回路由时沿用正在发送的控制器，避免取消首条消息。
      if (widget.sessionId == _activeSessionId) return;
      _activeSessionId = widget.sessionId;
      _conversation?.open(_activeSessionId);
      _resetComposer();
    }
  }

  void _resetComposer() {
    _selectedImages.clear();
    _selectedRoles.clear();
    _selectedAssets.clear();
    _mentionMode = false;
    _messageController.setText('');
    _messageController.dismissKeyboard();
  }

  @override
  void dispose() {
    _conversation?.dispose();
    _messageController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    if (_keyboardHeight == 0 && keyboardHeight > 0) {
      if (_bodyScrollController.hasClients) {
        _bodyOffsetBeforeKeyboard = _bodyScrollController.offset;
      }
    } else if (_keyboardHeight > 0 && keyboardHeight == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_bodyScrollController.hasClients) return;
        final position = _bodyScrollController.position;
        final target = _bodyOffsetBeforeKeyboard
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        _bodyScrollController.jumpTo(target);
      });
    }
    _keyboardHeight = keyboardHeight;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (previous, next) {
      if (previous == next) return;
      setState(() {
        _activeSessionId = null;
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
    final contentBottomPadding = composerInset + 20;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProvider);
    final isLoggedIn = user != null;
    final pointsBalance = user?.allCoins ?? 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEDE9FD), Colors.white],
              ),
        color: isDark ? colorScheme.surface : null,
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
            onOpenConversation: (session) {
              setState(() {
                _activeSessionId = session.id;
                _conversation?.open(session.id);
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
            },
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
                      PopiAppBarActions(
                        rightPadding: 20,
                        membershipEntry: PopiMembershipEntry(
                          points: pointsBalance,
                          showPoints: isLoggedIn,
                          label: isLoggedIn
                              ? l10n.upgradeMembership
                              : l10n.goToLogin,
                          onTap: () => context.push(
                            isLoggedIn ? '/profile/membership' : '/login',
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
                if (_activeSessionId != null && _conversation != null)
                  Positioned.fill(
                    bottom: composerInset,
                    child: ConversationTimeline(
                      key: ValueKey(
                        '${_conversation!.userId}:$_activeSessionId',
                      ),
                      controller: _conversation!,
                    ),
                  )
                else
                  SingleChildScrollView(
                    key: const Key('popi-home-scroll'),
                    controller: _bodyScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      50,
                      20,
                      contentBottomPadding,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          children: [
                            _WelcomeCards(
                              prompts: [
                                (
                                  l10n.homePromptCreateIp,
                                  const Color(0xFFEDE7FD),
                                ),
                                (
                                  l10n.homePromptImproveAccount,
                                  const Color(0xFFFEF4E8),
                                ),
                                (
                                  l10n.homePromptHasReference,
                                  const Color(0xFFFEEEF6),
                                ),
                                (
                                  l10n.homePromptUnsure,
                                  const Color(0xFFE5FBFA),
                                ),
                              ],
                              onPromptSelected: _selectPrompt,
                            ),
                          ],
                        ),
                      ),
                    ),
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
                            conversationMode: _activeSessionId != null,
                            controller: _messageController,
                            selectedImages: _selectedImages,
                            selectedRoles: _selectedRoles,
                            onRemoveRole: _removeSelectedRole,
                            selectedAssets: _selectedAssets,
                            onRemoveAsset: _removeSelectedAsset,
                            onAttachment: _showAttachmentSheet,
                            onRemoveImage: _removeSelectedImage,
                            onHeightChanged: _handleComposerHeightChanged,
                            onSubmitted: _openConversation,
                            sending:
                                (_conversation?.pending ?? false) ||
                                (_conversation?.loading ?? false),
                            running: _conversation?.running ?? false,
                            onStop: () => _conversation?.stop(),
                            onMentionRequested: _showMentionSheet,
                            onModelParametersRequested: _showModelParameters,
                            modelParametersDescription: [
                              _generationSettings.model.label,
                              '${l10n.roleVideoPreference}: ${_generationSettings.videoResolution}P / ${_generationSettings.videoRatio.label}',
                              '${l10n.roleImagePreference}: ${_generationSettings.imageResolution}P / ${_generationSettings.imageRatio.label}',
                              '${l10n.roleQuantity}: ${_generationSettings.quantity}',
                            ].join('\n'),
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

  void _bindConversation() {
    _conversation?.dispose();
    final userId = ref.read(userProvider)?.id;
    _conversation = userId == null
        ? null
        : ConversationController(
            ref.read(sessionRepositoryProvider),
            userId,
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
    final conversation = _conversation;
    if (conversation == null || conversation.pending || conversation.running) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final success = await conversation.send(
      value.trim(),
      [
        for (final image in _selectedImages)
          (name: image.name, bytes: image.bytes),
      ],
      l10n.newSessionTitle,
      _selectedImages.isEmpty &&
              _selectedAssets.isEmpty &&
              _selectedRoles.isNotEmpty
          ? l10n.chatRolePrompt
          : l10n.chatMediaPrompt,
      roleIds: _selectedRoles.map((role) => role.id).toList(),
      assets: List.of(_selectedAssets),
    );
    if (!mounted || !identical(conversation, _conversation)) return;
    if (success) {
      setState(_resetComposer);
      GoRouter.maybeOf(context)?.replace(
        Uri(
          path: '/session',
          queryParameters: {'sessionId': conversation.sessionId!},
        ).toString(),
      );
    } else if (conversation.error != null) {
      AppToast.error(context, conversationErrorText(conversation.error, l10n));
    }
  }

  Future<void> _showModelParameters() async {
    if (_generationSheetOpen) return;
    _generationSheetOpen = true;
    _messageController.dismissKeyboard();
    try {
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
      if (!mounted) return;
      if (selected.isNotEmpty) {
        setState(() => _selectedImages.addAll(selected));
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
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _showAttachmentSheet() async {
    if (_conversation?.pending ?? false) return;
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
    if (!mounted || result == null) return;
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

class _WelcomeCards extends StatelessWidget {
  const _WelcomeCards({required this.prompts, required this.onPromptSelected});

  final List<(String, Color)> prompts;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 400 / 509,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 509,
          child: Stack(
            children: [
              Positioned(
                left: 15,
                top: 0,
                width: 370,
                child: Text(
                  l10n.homeGreetingTitle.trim(),
                  key: const Key('popi-wordmark'),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              Positioned(
                left: 15,
                top: 66,
                width: 200,
                height: 120,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 200,
                    child: Text(
                      '${l10n.homeGreetingBody}\n${l10n.homePromptIntro}\n${l10n.homePromptQuestion}',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 208,
                top: 58,
                width: 184,
                height: 222,
                child: Image.asset(
                  'assets/images/home_welcome_character.png',
                  key: const Key('popi-welcome-mascot'),
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 199,
                height: 310,
                child: Container(
                  key: const Key('home-welcome-panel'),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: dark ? colors.surfaceContainerLow : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!dark)
                        Image.asset(
                          'assets/images/home_prompt_background.png',
                          fit: BoxFit.fill,
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            for (var i = 0; i < prompts.length; i++) ...[
                              _PromptTile(
                                index: i,
                                label: prompts[i].$1,
                                iconColor: prompts[i].$2,
                                onTap: () => onPromptSelected(prompts[i].$1),
                              ),
                              if (i < prompts.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
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

class _PromptTile extends StatelessWidget {
  const _PromptTile({
    required this.index,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  final int index;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  static const _icons = [
    'new_ip',
    'improve_account',
    'reference_account',
    'explore_direction',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark
          ? colors.surfaceContainerHigh
          : Colors.white.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        key: Key('home-prompt-$index'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppSvgIcon.asset(
                    'home_prompt_${_icons[index]}',
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: AppSvgIcon.asset(
                      'home_welcome_chevron',
                      color: colors.onSurface,
                      semanticsLabel: AppLocalizations.of(
                        context,
                      )!.selectAction,
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
