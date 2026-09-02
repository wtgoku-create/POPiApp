import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../home/presentation/widgets/popi_navigation_drawer.dart';

enum AssetLibrarySection { history, works, roles }

class AssetsPage extends StatefulWidget {
  const AssetsPage({
    super.key,
    this.hasSampleContent = false,
    this.initialSection = AssetLibrarySection.history,
  });

  const AssetsPage.sample({
    super.key,
    this.initialSection = AssetLibrarySection.history,
  }) : hasSampleContent = true;

  final bool hasSampleContent;
  final AssetLibrarySection initialSection;

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AssetLibrarySection _section;
  int _selectedFilter = 0;
  bool _selectingWorks = false;
  final Set<int> _selectedWorks = {};
  late List<_WorkGroup> _workGroups;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _workGroups = widget.hasSampleContent
        ? _sampleWorkGroups
            .map((group) => _WorkGroup(group.date, List.of(group.items)))
            .toList()
        : [];
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight =
        math.max(MediaQuery.paddingOf(context).top, 52).toDouble();
    final showFilters =
        _section != AssetLibrarySection.roles || widget.hasSampleContent;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PopiNavigationDrawer(),
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          SizedBox(height: statusBarHeight),
          _LibraryNavigation(
            selected: _section,
            onBackPressed: _goBack,
            onSelected: _changeSection,
          ),
          if (showFilters) ...[
            const SizedBox(height: 10),
            _SectionFilters(
              section: _section,
              selected: _selectedFilter,
              selectingWorks: _selectingWorks,
              onSelected: (index) => setState(() => _selectedFilter = index),
              onToggleSelection: _toggleSelectionMode,
            ),
          ],
          Expanded(child: _buildSection()),
        ],
      ),
    );
  }

  Widget _buildSection() {
    if (!widget.hasSampleContent) {
      return _LibraryEmptyState(section: _section);
    }

    return switch (_section) {
      AssetLibrarySection.history => const _HistoryList(),
      AssetLibrarySection.works => _WorksLibrary(
          groups: _workGroups,
          selecting: _selectingWorks,
          selected: _selectedWorks,
          onToggle: _toggleWork,
          onDownload: _downloadSelected,
          onDelete: _deleteSelected,
        ),
      AssetLibrarySection.roles => _RolesGrid(filter: _selectedFilter),
    };
  }

  void _changeSection(AssetLibrarySection section) {
    if (_section == section) return;
    setState(() {
      _section = section;
      _selectedFilter = 0;
      _selectingWorks = false;
      _selectedWorks.clear();
    });
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
      return;
    }
    GoRouter.maybeOf(context)?.go('/');
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectingWorks = !_selectingWorks;
      _selectedWorks.clear();
      if (_selectingWorks && _workGroups.isNotEmpty) {
        _selectedWorks.addAll([0, 1]);
      }
    });
  }

  void _toggleWork(int index) {
    if (!_selectingWorks) return;
    setState(() {
      if (!_selectedWorks.add(index)) _selectedWorks.remove(index);
    });
  }

  void _downloadSelected() {
    if (_selectedWorks.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已下载${_selectedWorks.length}个作品')),
    );
  }

  void _deleteSelected() {
    if (_selectedWorks.isEmpty) return;
    var flatIndex = 0;
    final groups = <_WorkGroup>[];
    for (final group in _workGroups) {
      final kept = <_WorkItem>[];
      for (final item in group.items) {
        if (!_selectedWorks.contains(flatIndex)) kept.add(item);
        flatIndex++;
      }
      if (kept.isNotEmpty) groups.add(_WorkGroup(group.date, kept));
    }
    setState(() {
      _workGroups = groups;
      _selectedWorks.clear();
      _selectingWorks = false;
    });
  }
}

class _LibraryNavigation extends StatelessWidget {
  const _LibraryNavigation({
    required this.selected,
    required this.onBackPressed,
    required this.onSelected,
  });

  final AssetLibrarySection selected;
  final VoidCallback onBackPressed;
  final ValueChanged<AssetLibrarySection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 20),
          SizedBox.square(
            dimension: 30,
            child: IconButton(
              key: const Key('assets-navigation-back'),
              tooltip: '返回上一页',
              padding: EdgeInsets.zero,
              onPressed: onBackPressed,
              icon: Transform.rotate(
                angle: math.pi / 2,
                child: const AppSvgIcon.asset(
                  'assets_history_chevron',
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          _LibraryTab(
            label: '创作历史',
            selected: selected == AssetLibrarySection.history,
            onTap: () => onSelected(AssetLibrarySection.history),
          ),
          const SizedBox(width: 20),
          _LibraryTab(
            label: '资产库',
            selected: selected == AssetLibrarySection.works,
            onTap: () => onSelected(AssetLibrarySection.works),
          ),
          const SizedBox(width: 20),
          _LibraryTab(
            label: '角色库',
            selected: selected == AssetLibrarySection.roles,
            onTap: () => onSelected(AssetLibrarySection.roles),
          ),
        ],
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('assets-section-$label'),
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionFilters extends StatelessWidget {
  const _SectionFilters({
    required this.section,
    required this.selected,
    required this.selectingWorks,
    required this.onSelected,
    required this.onToggleSelection,
  });

  final AssetLibrarySection section;
  final int selected;
  final bool selectingWorks;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleSelection;

  List<String> get _labels => switch (section) {
        AssetLibrarySection.history => ['全部', 'Agent账号模式', 'Vlog', '短剧'],
        AssetLibrarySection.works => ['全部', '图片', '视频'],
        AssetLibrarySection.roles => ['全部', 'AI真人', '二次元', '3D'],
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('assets-history-filters'),
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(left: 20),
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
                      color:
                          active ? AppColors.surfaceTint : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      _labels[index],
                      style: TextStyle(
                        color:
                            active ? AppColors.brand : AppColors.textTertiary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (section == AssetLibrarySection.works)
            SizedBox(
              width: selectingWorks ? 64 : 48,
              child: TextButton(
                key: const Key('assets-toggle-selection'),
                onPressed: onToggleSelection,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.textPrimary,
                ),
                child: selectingWorks
                    ? const Text('取消', style: TextStyle(fontSize: 16))
                    : const Icon(Icons.format_list_bulleted, size: 22),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({required this.section});

  final AssetLibrarySection section;

  @override
  Widget build(BuildContext context) {
    if (section == AssetLibrarySection.roles) {
      return Center(
        child: Transform.translate(
          offset: const Offset(0, -55),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/assets_roles_empty_art.png',
                width: 296.05,
                height: 186.1,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              const Text(
                '暂无角色',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '创建角色为你的视频增添人物资产',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 30 / 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isHistory = section == AssetLibrarySection.history;
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 55,
              height: 62,
              child: AppSvgIcon.asset('assets_works_empty'),
            ),
            const SizedBox(height: 10),
            Text(
              isHistory ? '暂无历史' : '暂无作品',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isHistory ? '开启Agent对话\n创建属于你的短视频账号' : '你创造的图片、视频、音频在这里',
              textAlign: TextAlign.center,
              style: const TextStyle(
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

class _HistoryList extends StatelessWidget {
  const _HistoryList();

  static const _times = [
    '12:27',
    '昨天',
    '7天前',
    '30天前',
    '30天前',
    '30天前',
    '30天前',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('assets-history-list'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      itemCount: _times.length,
      itemExtent: 104,
      itemBuilder: (context, index) => _HistoryItem(
        time: _times[index],
        current: index == 0,
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.time, required this.current});

  final String time;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Image.asset(
              'assets/images/assets_history_item.png',
              width: 74,
              height: 74,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Agent账号模式',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            time,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '有没有你喜欢、想学习的账号有...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (current) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/assets_points.png',
                              width: 15,
                              height: 10,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 3),
                            const Text.rich(
                              TextSpan(
                                text: '本次消耗',
                                children: [
                                  TextSpan(
                                    text: '44',
                                    style: TextStyle(color: AppColors.brand),
                                  ),
                                  TextSpan(text: '积分'),
                                ],
                              ),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (current)
                    Positioned(
                      right: 0,
                      top: 17,
                      child: Container(
                        width: 97,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTintStrong,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: const Text(
                          '继续任务',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorksLibrary extends StatelessWidget {
  const _WorksLibrary({
    required this.groups,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onDownload,
    required this.onDelete,
  });

  final List<_WorkGroup> groups;
  final bool selecting;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _LibraryEmptyState(section: AssetLibrarySection.works);
    }

    var offset = 0;
    final sections = <Widget>[];
    for (final group in groups) {
      final groupOffset = offset;
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              group.date,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
      sections.add(
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: group.items.length,
          itemBuilder: (context, index) {
            final globalIndex = groupOffset + index;
            return _WorkTile(
              key: Key('assets-work-$globalIndex'),
              item: group.items[index],
              selecting: selecting,
              selectionNumber: selected.contains(globalIndex)
                  ? selected.toList().indexOf(globalIndex) + 1
                  : null,
              onTap: () => onToggle(globalIndex),
            );
          },
        ),
      );
      sections.add(const SizedBox(height: 20));
      offset += group.items.length;
    }

    return Stack(
      children: [
        ListView(
          key: const Key('assets-works-grid'),
          padding: EdgeInsets.fromLTRB(20, 10, 20, selecting ? 120 : 20),
          children: sections,
        ),
        if (selecting)
          Align(
            alignment: Alignment.bottomCenter,
            child: _SelectionActions(
              hasSelection: selected.isNotEmpty,
              onDownload: onDownload,
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({
    super.key,
    required this.item,
    required this.selecting,
    required this.selectionNumber,
    required this.onTap,
  });

  final _WorkItem item;
  final bool selecting;
  final int? selectionNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              selecting ? item.selectionAsset : item.asset,
              fit: BoxFit.cover,
            ),
            if (selecting)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectionNumber == null
                        ? Colors.white.withValues(alpha: .92)
                        : AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: selectionNumber == null
                      ? null
                      : Text(
                          '$selectionNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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

class _SelectionActions extends StatelessWidget {
  const _SelectionActions({
    required this.hasSelection,
    required this.onDownload,
    required this.onDelete,
  });

  final bool hasSelection;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('assets-selection-actions'),
      height: 104,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SelectionAction(
            icon: Icons.file_download_outlined,
            label: '下载',
            enabled: hasSelection,
            onTap: onDownload,
          ),
          _SelectionAction(
            icon: Icons.delete_outline,
            label: '删除',
            color: const Color(0xFFF05A5A),
            enabled: hasSelection,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  const _SelectionAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color.withValues(alpha: enabled ? 1 : .35),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: enabled ? 1 : .35),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolesGrid extends StatelessWidget {
  const _RolesGrid({required this.filter});

  final int filter;

  @override
  Widget build(BuildContext context) {
    final indices = switch (filter) {
      1 => [4, 7, 13, 14],
      2 => [1, 2, 6, 8, 11],
      3 => [0, 3, 5, 9, 10],
      _ => List.generate(15, (index) => index),
    };

    return GridView.builder(
      key: const Key('assets-roles-grid'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: indices.length,
      itemBuilder: (context, index) {
        final assetIndex = indices[index] + 1;
        return Image.asset(
          'assets/images/assets_role_grid_${assetIndex.toString().padLeft(2, '0')}.png',
          width: 128,
          height: 128,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _WorkGroup {
  const _WorkGroup(this.date, this.items);

  final String date;
  final List<_WorkItem> items;
}

class _WorkItem {
  const _WorkItem(
    this.asset, {
    required this.selectionAsset,
  });

  final String asset;
  final String selectionAsset;
}

const _sampleWorkGroups = [
  _WorkGroup('2026.09.01', [
    _WorkItem(
      'assets/images/assets_works_gallery_01.png',
      selectionAsset: 'assets/images/assets_works_selection_01.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_02.png',
      selectionAsset: 'assets/images/assets_works_selection_02.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_03.png',
      selectionAsset: 'assets/images/assets_works_selection_03.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_04.png',
      selectionAsset: 'assets/images/assets_works_selection_04.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_05.png',
      selectionAsset: 'assets/images/assets_works_selection_05.png',
    ),
  ]),
  _WorkGroup('2026.08.31', [
    _WorkItem(
      'assets/images/assets_works_gallery_06.png',
      selectionAsset: 'assets/images/assets_works_selection_06.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_07.png',
      selectionAsset: 'assets/images/assets_works_selection_07.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_08.png',
      selectionAsset: 'assets/images/assets_works_selection_08.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_09.png',
      selectionAsset: 'assets/images/assets_works_selection_09.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_10.png',
      selectionAsset: 'assets/images/assets_works_selection_10.png',
    ),
  ]),
];
