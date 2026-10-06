import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../home/presentation/widgets/popi_navigation_drawer.dart';
import 'role_library_list.dart';
import 'asset_preview_page.dart';

enum AssetLibrarySection { works, roles }

class AssetsPage extends StatefulWidget {
  const AssetsPage({
    super.key,
    this.hasSampleContent = false,
    this.initialSection = AssetLibrarySection.works,
  });

  const AssetsPage.sample({
    super.key,
    this.initialSection = AssetLibrarySection.works,
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

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PopiNavigationDrawer(),
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF5F4FA)
          : Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          SizedBox(height: statusBarHeight),
          _LibraryNavigation(
            selected: _section,
            onBackPressed: _goBack,
            onSelected: _changeSection,
          ),
          ...[
            const SizedBox(height: 10),
            _SectionFilters(
              section: _section,
              selected: _selectedFilter,
              selectingWorks: _selectingWorks,
              onSelected: (index) => setState(() {
                _selectedFilter = index;
                _selectedWorks.clear();
              }),
              onToggleSelection: _toggleSelectionMode,
            ),
          ],
          if (_section == AssetLibrarySection.roles) const SizedBox(height: 16),
          Expanded(child: _buildSection()),
        ],
      ),
    );
  }

  Widget _buildSection() {
    if (_section == AssetLibrarySection.roles) {
      return RoleLibraryList(
          category: _selectedFilter == 0 ? 'official' : 'personal');
    }
    if (!widget.hasSampleContent) {
      return _LibraryEmptyState(section: _section);
    }

    return switch (_section) {
      AssetLibrarySection.works => _WorksLibrary(
          groups: _workGroups,
          filter: _selectedFilter,
          selecting: _selectingWorks,
          selected: _selectedWorks,
          onToggle: _toggleWork,
          onPreview: _previewWork,
          onLongPress: (index) => setState(() {
            _selectingWorks = true;
            _selectedWorks.add(index);
          }),
          onDownload: _downloadSelected,
          onDelete: _deleteSelected,
        ),
      AssetLibrarySection.roles => throw StateError('Roles handled above'),
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
          AppLocalizations.of(context)!.assetDownloadUnavailable,
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedWorks.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialog.confirm(
        context: context,
        title: l10n.deleteAssetsTitle,
        description: l10n.deleteAssetsDescription(_selectedWorks.length),
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.delete,
        confirmKey: const Key('confirm-delete-assets'),
        destructive: true);
    if (confirmed != true || !mounted) return;
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

  void _previewWork(int index) {
    final item = _workGroups.expand((group) => group.items).elementAt(index);
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (context) => AssetPreviewPage(
        asset: item.asset,
        isVideo: item.isVideo,
      ),
    ));
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
          const SizedBox(width: 10),
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadii.pill)),
            child: Row(children: [
              Expanded(
                  child: _LibraryTab(
                label: l10n.assetLibrary,
                selected: selected == AssetLibrarySection.works,
                onTap: () => onSelected(AssetLibrarySection.works),
              )),
              Expanded(
                  child: _LibraryTab(
                label: l10n.roleLibrary,
                selected: selected == AssetLibrarySection.roles,
                onTap: () => onSelected(AssetLibrarySection.roles),
              )),
            ]),
          )),
          const SizedBox(width: 20),
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
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill)),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
      AssetLibrarySection.works => [
          l10n.filterAll,
          l10n.images,
          l10n.videos,
        ],
      AssetLibrarySection.roles => [
          l10n.officialRoles,
          l10n.myRoles,
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
                      color: active
                          ? section == AssetLibrarySection.roles
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.05)
                              : AppColors.surfaceTint
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: active
                            ? section == AssetLibrarySection.roles
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.black
                            : AppColors.textTertiary,
                        fontSize:
                            section == AssetLibrarySection.roles ? 14 : 16,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
                    : Tooltip(
                        message: l10n.selectAssets,
                        child: const Icon(Icons.checklist, size: 22)),
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
              l10n.noWorks,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTypeSizes.pageTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.noWorksDescription,
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

class _WorksLibrary extends StatelessWidget {
  const _WorksLibrary({
    required this.groups,
    required this.filter,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onPreview,
    required this.onLongPress,
    required this.onDownload,
    required this.onDelete,
  });

  final List<_WorkGroup> groups;
  final int filter;
  final bool selecting;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onPreview;
  final ValueChanged<int> onLongPress;
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
      final visible = [
        for (var i = 0; i < group.items.length; i++)
          if (filter == 0 || (filter == 2) == group.items[i].isVideo) i
      ];
      offset += group.items.length;
      if (visible.isEmpty) continue;
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
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final itemIndex = visible[index];
            final globalIndex = groupOffset + itemIndex;
            return _WorkTile(
              key: Key('assets-work-$globalIndex'),
              item: group.items[itemIndex],
              selecting: selecting,
              selectionNumber: selected.contains(globalIndex)
                  ? selected.toList().indexOf(globalIndex) + 1
                  : null,
              onTap: () =>
                  selecting ? onToggle(globalIndex) : onPreview(globalIndex),
              onLongPress: () => onLongPress(globalIndex),
            );
          },
        ),
      );
      sections.add(const SizedBox(height: 20));
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
              selectionCount: selected.length,
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
    required this.onLongPress,
  });

  final _WorkItem item;
  final bool selecting;
  final int? selectionNumber;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              item.asset,
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
    required this.selectionCount,
    required this.onDownload,
    required this.onDelete,
  });

  final bool hasSelection;
  final int selectionCount;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('assets-selection-actions'),
      height: 104 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Text(l10n.selectedAssets(selectionCount),
            style: Theme.of(context).textTheme.labelMedium),
        Expanded(
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
        )),
      ]),
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

class _WorkGroup {
  const _WorkGroup(this.date, this.items);

  final String date;
  final List<_WorkItem> items;
}

class _WorkItem {
  const _WorkItem(
    this.asset, {
    required this.selectionAsset,
    this.isVideo = false,
  });

  final String asset;
  final String selectionAsset;
  final bool isVideo;
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
      isVideo: true,
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
      isVideo: true,
      selectionAsset: 'assets/images/assets_works_selection_09.png',
    ),
    _WorkItem(
      'assets/images/assets_works_gallery_10.png',
      isVideo: true,
      selectionAsset: 'assets/images/assets_works_selection_10.png',
    ),
  ]),
];
