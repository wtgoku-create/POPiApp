import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../home/presentation/widgets/popi_navigation_drawer.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({this.showWorks = true, super.key});

  final bool showWorks;

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late bool _showWorks = widget.showWorks;
  int _selectedTab = 0;

  static const _works = [
    'assets_works_thumbnail-01.png',
    'assets_works_thumbnail-02.png',
    'assets_works_thumbnail-03.png',
    'assets_works_thumbnail-04.png',
    'assets_works_thumbnail-05.png',
    'assets_works_thumbnail-06.png',
    'assets_works_thumbnail-07.png',
    'assets_works_thumbnail-08.png',
    'assets_works_thumbnail-09.png',
    'assets_works_thumbnail-09.png',
    'assets_works_thumbnail-10.png',
    'assets_works_thumbnail-11.png',
    'assets_works_thumbnail-12.png',
    'assets_works_thumbnail-13.png',
    'assets_works_thumbnail-14.png',
  ];

  @override
  Widget build(BuildContext context) {
    final top = math.max(MediaQuery.paddingOf(context).top, 52).toDouble();
    return Scaffold(
      key: _scaffoldKey,
      drawer: const PopiNavigationDrawer(),
      body: Column(
        children: [
          SizedBox(
            height: top + 56,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  SizedBox.square(
                    dimension: 40,
                    child: IconButton(
                      tooltip: '打开导航',
                      padding: const EdgeInsets.all(5),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      icon: const AppSvgIcon.asset(
                        'common_navigation_menu',
                        size: 30,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox.square(
                    dimension: 40,
                    child: IconButton(
                      tooltip: '个人设置',
                      padding: const EdgeInsets.all(5),
                      onPressed: () => context.push('/profile'),
                      icon: const Icon(Icons.settings_outlined, size: 30),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
              ),
              child: Column(
                children: [
                  _AssetTabs(
                    selected: _selectedTab,
                    onSelected: (index) {
                      setState(() {
                        _selectedTab = index;
                        if (index != 0) _showWorks = false;
                      });
                    },
                  ),
                  Expanded(
                    child: _showWorks && _selectedTab == 0
                        ? _WorksGrid(works: _works)
                        : const _EmptyWorks(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetTabs extends StatelessWidget {
  const _AssetTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['作品', '脚本', '收藏'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(labels.length, (index) {
          final active = selected == index;
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: () => onSelected(index),
            child: Container(
              width: 113,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.surfaceTint : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: active ? AppColors.brand : AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _WorksGrid extends StatelessWidget {
  const _WorksGrid({required this.works});

  final List<String> works;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const Key('assets-works-grid'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 76),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: works.length,
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/${works[index]}',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _EmptyWorks extends StatelessWidget {
  const _EmptyWorks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -20),
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
              '暂无作品',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              '你创造的图片、视频、音频在这里',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 30 / 16,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 110,
              height: 50,
              child: FilledButton(
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
