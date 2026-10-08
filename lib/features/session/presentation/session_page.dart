import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../attachments/presentation/attachment_picker_sheet.dart';
import 'widgets/popi_message_composer.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../../../shared/widgets/popi_membership_entry.dart';

/// Creation session with a prompt composer and attachment selection.
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({this.pickImages, this.initialPrompt, super.key});

  final Future<List<XFile>> Function()? pickImages;
  final String? initialPrompt;

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
  bool _mentionMode = false;

  static const _maxImageCount = 5;
  static const _maxImageBytes = 6 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectPrompt(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
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
    final l10n = AppLocalizations.of(context)!;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final composerBottomPadding = math
        .max(safeArea.bottom, keyboardHeight + 20)
        .toDouble();
    final fallbackComposerHeight = 8 + 60 + 10 + 14 + composerBottomPadding;
    final composerInset = _composerHeight > 0
        ? _composerHeight
        : fallbackComposerHeight;
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
            onNewProject: () => _selectPrompt(l10n.homePromptCreateIp),
            onOpenConversation: (selection) =>
                _openConversation(selection.session.id),
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
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: PopiMembershipEntry(
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
                              (l10n.homePromptUnsure, const Color(0xFFE5FBFA)),
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
                  bottom: 0,
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
                            controller: _messageController,
                            selectedImages: _selectedImages,
                            onAttachment: _showAttachmentSheet,
                            onRemoveImage: _removeSelectedImage,
                            onHeightChanged: _handleComposerHeightChanged,
                            onSubmitted: _openConversation,
                            onMentionRequested: _showMentionSheet,
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

  void _openConversation(String value) {
    if (value.trim().isEmpty) return;
    AppToast.info(context, AppLocalizations.of(context)!.conversationPending);
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
    final remaining = _maxImageCount - _selectedImages.length;
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
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _showAttachmentSheet() async {
    final remaining = _maxImageCount - _selectedImages.length;
    if (remaining <= 0) {
      AppToast.info(context, AppLocalizations.of(context)!.maximumImageCount);
      return;
    }
    _messageController.dismissKeyboard();
    final result = await AttachmentPickerSheet.show(
      context: context,
      limit: remaining,
      pickImages: widget.pickImages,
    );
    if (!mounted || result == null) return;
    if (result.library != null) {
      await context.push(
        '/assets?section=${result.library == AttachmentLibrary.roles ? 'roles' : 'works'}',
      );
    } else {
      await _addImages(result.images);
    }
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
