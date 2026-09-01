import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../shared/providers/safe_area_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

class PopiNavigationDrawer extends ConsumerStatefulWidget {
  const PopiNavigationDrawer({super.key});

  @override
  ConsumerState<PopiNavigationDrawer> createState() =>
      _PopiNavigationDrawerState();
}

class _PopiNavigationDrawerState extends ConsumerState<PopiNavigationDrawer> {
  final _searchController = TextEditingController();

  static const _tasks = [
    ('生活剧情Vlog', 'popi_task_red'),
    ('抖音AI漫剧博主', 'popi_task_blue'),
    ('角色介绍撰写', 'popi_task_gold'),
    ('AI与插画师打造卡通IP角色功能', 'popi_task_neutral'),
    ('人类渲染图生成需求', 'popi_task_neutral'),
    ('搞笑视频相关话题', 'popi_task_neutral'),
    ('IP商业化模式', 'popi_task_neutral'),
    ('简约商务PPT模板', 'popi_task_neutral'),
    ('生成上海东方明珠繁华背景图', 'popi_task_neutral'),
    ('推荐短视频博主', 'popi_task_neutral'),
    ('当前微博话题热度排行榜', 'popi_task_neutral'),
    ('搞笑剧情Vlog', 'popi_task_neutral'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final topInset = math.max(safeArea.top, 53.0);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: math.min(360, MediaQuery.sizeOf(context).width * .9),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            offset: Offset(6, 0),
            blurRadius: 30,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topInset, 20, 20),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          key: const Key('popi-drawer-search'),
                          height: 40,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colorScheme.surfaceContainerHigh
                                      : colorScheme.surface,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(AppRadii.pill),
                                  ),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: isDark ? 0.65 : 1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.14 : 0.05,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              TextField(
                                controller: _searchController,
                                cursorColor: colorScheme.primary,
                                expands: true,
                                minLines: null,
                                maxLines: null,
                                textAlignVertical: TextAlignVertical.center,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 20 / 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: '搜索对话',
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 20 / 14,
                                  ),
                                  isDense: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.only(
                                    left: 40,
                                    right: 30,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 10,
                                child: IgnorePointer(
                                  child: AppSvgIcon.asset(
                                    'popi_search',
                                    size: 30,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      _NavigationItem(
                        iconAsset: 'popi_nav_conversation',
                        label: 'POPi对话',
                        onTap: () => _openRoute(context, '/'),
                      ),
                      _NavigationItem(
                        iconAsset: 'popi_nav_role',
                        iconWidth: 18.4994,
                        iconHeight: 20.716,
                        flipIconVertically: true,
                        label: '角色',
                        onTap: () => _openRoute(context, '/profile'),
                      ),
                      _NavigationItem(
                        iconAsset: 'popi_nav_asset',
                        label: '资产',
                        onTap: () => _openRoute(context, '/assets'),
                      ),
                      _NavigationItem(
                        iconAsset: 'popi_nav_inspiration',
                        iconWidth: 20.1321,
                        iconHeight: 18.8766,
                        flipIconVertically: true,
                        label: '灵感库',
                        onTap: () => _showPending(context, '灵感库功能待接入'),
                      ),
                      _NavigationItem(
                        iconAsset: 'popi_nav_skill',
                        label: 'Skill',
                        onTap: () => _openRoute(context, '/profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 9),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '任务',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                AppSvgIcon.asset(
                                  'popi_more',
                                  size: 30,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemExtent: 40,
                            itemCount: _tasks.length,
                            itemBuilder: (context, index) {
                              final task = _tasks[index];
                              return _TaskItem(
                                label: task.$1,
                                iconAsset: task.$2,
                                onTap: () {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  Navigator.pop(context);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(task.$1)),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _DrawerFooter(
              onNotification: () => _showPending(context, '通知'),
              onSettings: () => _openRoute(context, '/profile'),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoute(BuildContext context, String route) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(route);
  }

  void _showPending(BuildContext context, String label) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text(label)),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.iconWidth = 30,
    this.iconHeight = 30,
    this.flipIconVertically = false,
  });

  final String iconAsset;
  final double iconWidth;
  final double iconHeight;
  final bool flipIconVertically;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary.withValues(alpha: .12);
          }
          return Colors.transparent;
        }),
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 30),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: Center(
                    child: Transform.flip(
                      flipY: flipIconVertically,
                      child: SizedBox(
                        width: iconWidth,
                        height: iconHeight,
                        child: AppSvgIcon.asset(iconAsset, color: color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
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

class _TaskItem extends StatelessWidget {
  const _TaskItem({
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNeutralIcon = iconAsset == 'popi_task_neutral';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary.withValues(alpha: .12);
          }
          return Colors.transparent;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              AppSvgIcon.asset(
                iconAsset,
                size: 30,
                colorMapper: isNeutralIcon && isDark
                    ? _NeutralTaskIconColorMapper(
                        background: colorScheme.surfaceContainerHighest,
                        foreground: colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
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

class _NeutralTaskIconColorMapper extends ColorMapper {
  const _NeutralTaskIconColorMapper({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == const Color(0xFFE8E8E8)) {
      return background;
    }
    if (color == Colors.white) {
      return foreground;
    }
    return color;
  }
}

class _DrawerFooter extends ConsumerWidget {
  const _DrawerFooter({
    required this.onNotification,
    required this.onSettings,
  });

  final VoidCallback onNotification;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = user?.name.isNotEmpty == true ? user!.name : '--';
    final displayId =
        user?.code.isNotEmpty == true ? user!.code : user?.id ?? '--';

    return SizedBox(
      height: 47,
      child: Row(
        children: [
          ClipOval(
            child: user?.avatarUrl?.isNotEmpty == true
                ? Image.network(
                    user!.avatarUrl!,
                    width: 47,
                    height: 47,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  )
                : _defaultAvatar(),
          ),
          const SizedBox(width: 10),
          Expanded(
            key: const Key('drawer-user-summary'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 16,
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(height: 5),
                SizedBox(
                  height: 15,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          displayId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Image(
                        image: AssetImage(
                          'assets/icons/popi_user_badge.png',
                        ),
                        width: 15,
                        height: 15,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              tooltip: '通知',
              padding: const EdgeInsets.all(5),
              onPressed: onNotification,
              icon: AppSvgIcon.asset(
                'popi_notification',
                size: 30,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              tooltip: '个人设置',
              padding: const EdgeInsets.all(5),
              onPressed: onSettings,
              icon: AppSvgIcon.asset(
                'popi_user_chevron',
                size: 30,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() => Image.asset(
        'assets/icons/popi_user_avatar.png',
        width: 47,
        height: 47,
        fit: BoxFit.cover,
      );
}
