import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
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
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.downloadedWorks(_selectedWorks.length),
        ),
      ),
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
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 20),
          SizedBox.square(
            dimension: 30,
            child: IconButton(
              key: const Key('assets-navigation-back'),
              tooltip: l10n.backToPreviousPage,
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
            label: l10n.creationHistory,
            selected: selected == AssetLibrarySection.history,
            onTap: () => onSelected(AssetLibrarySection.history),
          ),
          const SizedBox(width: 20),
          _LibraryTab(
            label: l10n.assetLibrary,
            selected: selected == AssetLibrarySection.works,
            onTap: () => onSelected(AssetLibrarySection.works),
          ),
          const SizedBox(width: 20),
          _LibraryTab(
            label: l10n.roleLibrary,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = switch (section) {
      AssetLibrarySection.history => [
          l10n.filterAll,
          l10n.agentAccountMode,
          l10n.vlog,
          l10n.shortDrama,
        ],
      AssetLibrarySection.works => [
          l10n.filterAll,
          l10n.images,
          l10n.videos,
        ],
      AssetLibrarySection.roles => [
          l10n.filterAll,
          l10n.aiHuman,
          l10n.anime,
          l10n.threeD,
        ],
    };
    return SizedBox(
      key: const Key('assets-history-filters'),
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(left: 20),
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
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
                      labels[index],
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
                    ? Text(l10n.cancel, style: const TextStyle(fontSize: 16))
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
    final l10n = AppLocalizations.of(context)!;
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
              Text(
                l10n.noRoles,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTypeSizes.pageTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.noRolesDescription,
                style: const TextStyle(
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
              isHistory ? l10n.noHistory : l10n.noWorks,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTypeSizes.pageTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isHistory ? l10n.noHistoryDescription : l10n.noWorksDescription,
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
                child: Text(
                  l10n.goGenerate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _HistoryList extends StatelessWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final times = [
      '12:27',
      l10n.yesterday,
      l10n.daysAgo(7),
      for (var index = 0; index < 4; index++) l10n.daysAgo(30),
    ];
    return ListView.builder(
      key: const Key('assets-history-list'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      itemCount: times.length,
      itemExtent: 104,
      itemBuilder: (context, index) => _HistoryItem(
        time: times[index],
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
    final l10n = AppLocalizations.of(context)!;
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
                          Text(
                            l10n.agentAccountMode,
                            style: const TextStyle(
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
                      Text(
                        l10n.sampleAccountQuestion,
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
                            Text(
                              l10n.pointsSpent(44),
                              style: const TextStyle(
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
                        child: Text(
                          l10n.continueTask,
                          style: const TextStyle(
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
    final l10n = AppLocalizations.of(context)!;
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
            label: l10n.download,
            enabled: hasSelection,
            onTap: onDownload,
          ),
          _SelectionAction(
            icon: Icons.delete_outline,
            label: l10n.delete,
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
    final roles = filter == 0
        ? _sampleRoles
        : _sampleRoles.where((role) => role.category == filter).toList();

    return ListView.separated(
      key: const Key('assets-roles-grid'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      itemCount: roles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final role = roles[index];
        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            key: Key('assets-role-${role.assetIndex}'),
            width: 400,
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/assets_role_list_${role.assetIndex.toString().padLeft(2, '0')}.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        role.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleItem {
  const _RoleItem({
    required this.assetIndex,
    required this.name,
    required this.description,
    required this.category,
  });

  final int assetIndex;
  final String name;
  final String description;
  final int category;
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

const _sampleRoles = [
  _RoleItem(
    assetIndex: 1,
    name: '夏禾',
    description: 'xxxxxxxxx',
    category: 2,
  ),
  _RoleItem(
    assetIndex: 2,
    name: '金发王子',
    description: 'xxxxxxxxx',
    category: 1,
  ),
  _RoleItem(
    assetIndex: 3,
    name: '人鱼公主',
    description: 'xxxxxxxxx',
    category: 1,
  ),
  _RoleItem(
    assetIndex: 4,
    name: '糯叽叽',
    description: 'xxxxxxxxx',
    category: 2,
  ),
  _RoleItem(
    assetIndex: 5,
    name: '花西冷少',
    description: 'xxxxxxxxx',
    category: 1,
  ),
  _RoleItem(
    assetIndex: 6,
    name: '莓莓',
    description: 'xxxxxxxxx',
    category: 3,
  ),
];
