import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import 'widgets/popi_message_composer.dart';
import 'widgets/popi_navigation_drawer.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _messageController = TextEditingController();
  final _bodyScrollController = ScrollController();
  bool _drawerOpen = false;
  bool _microphoneActive = false;
  double _keyboardHeight = 0;
  double _bodyOffsetBeforeKeyboard = 0;

  static const _prompts = [
    ('做一个新IP', Color(0xFFF3EFFF)),
    ('让我的老帐号变好', AppColors.surfaceTint),
    ('我已经有参考账号', Color(0xFFF0F4F9)),
    ('我还不知道做什么', AppColors.pageBackground),
  ];

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
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final composerBottomPadding = keyboardHeight > 0
        ? keyboardHeight + 20
        : (safeArea.bottom > 20 ? safeArea.bottom : 20);
    final composerClearance = 60.0 + 8 + composerBottomPadding + 20;

    return Scaffold(
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
                        tooltip: '打开导航',
                        padding: const EdgeInsets.all(5),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const AppSvgIcon.asset(
                          'popi_menu',
                          size: 30,
                          semanticsLabel: '打开导航',
                        ),
                      ),
                    ),
                  ),
                ),
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
              controller: _bodyScrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 10, 20, composerClearance),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/popi_wordmark.svg',
                        key: const Key('popi-wordmark'),
                        width: 80,
                        height: 53,
                        semanticsLabel: 'POPi',
                      ),
                      const SizedBox(height: 32),
                      _WelcomeCards(
                        prompts: _prompts,
                        onPromptSelected: (prompt) {
                          _messageController.text = prompt;
                          _messageController.selection =
                              TextSelection.collapsed(
                            offset: _messageController.text.length,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                heightFactor: 1,
                child: PopiMessageComposer(
                  controller: _messageController,
                  microphoneActive: _microphoneActive,
                  onAttachment: _showAttachmentSheet,
                  onMicrophone: () => setState(
                    () => _microphoneActive = !_microphoneActive,
                  ),
                  onSubmitted: _openConversation,
                ),
              ),
            ),
          ],
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
    AppToast.info(context, '对话功能待接入');
  }

  void _showAttachmentSheet() {
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
                    AppToast.info(context, '相册');
                  },
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('相册'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    AppToast.info(context, '文件');
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('文件'),
                ),
              ),
            ],
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
    return SizedBox(
      height: 541,
      child: Stack(
        children: [
          Container(
            height: 271,
            decoration: BoxDecoration(
              color: AppColors.surfaceTintStrong,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 30,
                  top: 57,
                  child: SizedBox(
                    width: 180,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '嗨，我是POPi~\n',
                            style: TextStyle(fontSize: 20),
                          ),
                          TextSpan(
                            text: '我来帮你一起\n把一个账号做起来！',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: AppColors.textPrimary,
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
                    'assets/icons/popi_welcome_mascot.png',
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
            top: 166,
            child: Container(
              height: 375,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '先告诉我：',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '你现在最想做什么？',
                        style: TextStyle(
                          color: AppColors.textPrimary,
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
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.pageBackground, endColor],
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: AppSvgIcon.asset(
                      'popi_chevron_right',
                      semanticsLabel: '选择',
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
