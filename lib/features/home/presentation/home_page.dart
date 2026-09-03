import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import 'widgets/popi_message_composer.dart';
import 'widgets/popi_navigation_drawer.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({this.pickImages, super.key});

  final Future<List<XFile>> Function()? pickImages;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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
    final composerBottomPadding =
        math.max(safeArea.bottom, keyboardHeight + 20).toDouble();
    final fallbackComposerHeight = 8 + 60 + 10 + 14 + composerBottomPadding;
    final composerInset =
        _composerHeight > 0 ? _composerHeight : fallbackComposerHeight;
    final contentBottomPadding = composerInset + 20;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pointsBalance = ref.watch(userProvider)?.allCoins ?? 0;

    return GestureDetector(
      key: const Key('popi-home-dismiss-keyboard'),
      behavior: HitTestBehavior.translucent,
      onTap: _messageController.dismissKeyboard,
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        drawer: const PopiNavigationDrawer(),
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
                  toolbarHeight: 56,
                  leadingWidth: 80,
                  leading: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
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
                        child: _MembershipEntry(
                          points: pointsBalance,
                          label: l10n.upgradeMembership,
                          onTap: () => context.push('/profile/membership'),
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
                padding: EdgeInsets.fromLTRB(20, 10, 20, contentBottomPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/home_welcome_logo.svg',
                          key: const Key('popi-wordmark'),
                          width: 80,
                          height: 53,
                          semanticsLabel: 'POPi',
                        ),
                        const SizedBox(height: 32),
                        _WelcomeCards(
                          prompts: [
                            (l10n.homePromptCreateIp, const Color(0xFFF3EFFF)),
                            (
                              l10n.homePromptImproveAccount,
                              AppColors.surfaceTint
                            ),
                            (
                              l10n.homePromptHasReference,
                              const Color(0xFFF0F4F9)
                            ),
                            (l10n.homePromptUnsure, AppColors.pageBackground),
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

  Future<void> _pickImageFromGallery() async {
    final remaining = _maxImageCount - _selectedImages.length;
    if (remaining <= 0) {
      AppToast.info(context, AppLocalizations.of(context)!.maximumImageCount);
      return;
    }

    try {
      final images = await (widget.pickImages?.call() ??
          ImagePicker().pickMultiImage(
            imageQuality: 85,
            maxWidth: 1920,
            limit: remaining,
          ));
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

  void _showAttachmentSheet() {
    final l10n = AppLocalizations.of(context)!;
    AppSheet.show<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _pickImageFromGallery();
                  },
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(l10n.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    AppToast.info(context, l10n.file);
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(l10n.file),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class _MembershipEntry extends StatelessWidget {
  const _MembershipEntry({
    required this.points,
    required this.label,
    required this.onTap,
  });

  final int points;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home-membership-entry'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Ink(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: isDark ? colorScheme.outlineVariant : AppColors.outline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: Center(
                    child: SizedBox(
                      width: 12,
                      height: 7.94,
                      child: const AppSvgIcon.asset(
                        'membership_points',
                        key: Key('home-membership-icon'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '$points',
                  key: const Key('home-membership-points'),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 1,
                  height: 12,
                  child: ColoredBox(color: colorScheme.outline),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  key: const Key('home-membership-label'),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1,
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

class _WelcomeCards extends StatelessWidget {
  const _WelcomeCards({
    required this.prompts,
    required this.onPromptSelected,
  });

  final List<(String, Color)> prompts;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 541,
      child: Stack(
        children: [
          Container(
            height: 271,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: isDark
                  ? Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    )
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 30,
                  top: 57,
                  child: SizedBox(
                    width: 180,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.homeGreetingTitle,
                            style: TextStyle(fontSize: 20),
                          ),
                          TextSpan(
                            text: l10n.homeGreetingBody,
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 196.5,
                  top: 30,
                  child: Image.asset(
                    'assets/icons/home_welcome_banner.png',
                    key: const Key('popi-welcome-mascot'),
                    width: 173,
                    height: 211,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: isDark ? 160 : 166,
            child: Container(
              key: const Key('home-welcome-panel'),
              height: isDark ? 381 : 375,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerLow
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: isDark
                    ? Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.45),
                      )
                    : null,
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.homePromptIntro,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.homePromptQuestion,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var index = 0; index < prompts.length; index++) ...[
                    _PromptTile(
                      label: prompts[index].$1,
                      endColor: prompts[index].$2,
                      onTap: () => onPromptSelected(prompts[index].$1),
                    ),
                    if (index != prompts.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({
    required this.label,
    required this.endColor,
    required this.onTap,
  });

  final String label;
  final Color endColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final end = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : endColor;
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.surfaceContainerHigh, end],
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AppSvgIcon.asset(
                      'home_welcome_chevron',
                      color: colorScheme.onSurfaceVariant,
                      semanticsLabel:
                          AppLocalizations.of(context)!.selectAction,
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
