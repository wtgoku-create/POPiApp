import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../home/presentation/widgets/popi_navigation_drawer.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final statusBarHeight =
        math.max(MediaQuery.paddingOf(context).top, 52).toDouble();

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PopiNavigationDrawer(),
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          SizedBox(height: statusBarHeight),
          _LibraryNavigation(
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(height: 10),
          _HistoryFilters(
            selected: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const Expanded(child: _EmptyHistory()),
        ],
      ),
    );
  }
}

class _LibraryNavigation extends StatelessWidget {
  const _LibraryNavigation({required this.onMenuPressed});

  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LibraryTab(label: '角色库'),
              SizedBox(width: 20),
              _LibraryTab(label: '资产库'),
              SizedBox(width: 20),
              _LibraryTab(label: '创作历史', selected: true),
            ],
          ),
          Positioned(
            right: 8,
            child: SizedBox.square(
              dimension: 40,
              child: IconButton(
                key: const Key('assets-navigation-menu'),
                tooltip: '打开导航',
                padding: EdgeInsets.zero,
                onPressed: onMenuPressed,
                icon: const AppSvgIcon.asset(
                  'assets_history_chevron',
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: selected ? AppColors.textPrimary : AppColors.textTertiary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = ['全部', 'Agent账号模式', 'Vlog', '短剧'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('assets-history-filters'),
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final active = selected == index;
          return InkWell(
            key: Key('assets-history-filter-$index'),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.surfaceTint : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                _labels[index],
                style: TextStyle(
                  color: active ? AppColors.brand : AppColors.textTertiary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 55,
              height: 62,
              child: AppSvgIcon.asset('assets_works_empty'),
            ),
            const SizedBox(height: 10),
            const Text(
              '暂无历史',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '开启Agent对话\n创建属于你的短视频账号',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 20 / 16,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 110,
              height: 50,
              child: FilledButton(
                key: const Key('assets-go-generate'),
                onPressed: () => context.go('/'),
                child: const Text(
                  '去生成',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
