import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/providers/network_provider.dart';
import '../data/work_library_repository.dart';
import '../domain/library_work.dart';
import 'role_library_list.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../../../shared/widgets/app_video_preview.dart';

enum AssetLibrarySection { works, roles }

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({
    super.key,
    this.hasSampleContent = false,
    this.isLoadingWorks = false,
    this.initialSection = AssetLibrarySection.works,
    this.repository,
  }) : _isSheet = false;

  const AssetsPage._sheet({required this.initialSection})
    : _isSheet = true,
      hasSampleContent = false,
      isLoadingWorks = false,
      repository = null;

  const AssetsPage.sample({
    super.key,
    this.isLoadingWorks = false,
    this.initialSection = AssetLibrarySection.works,
    this.repository,
  }) : hasSampleContent = true,
       _isSheet = false;

  static Future<void> showSheet({
    required BuildContext context,
    required AssetLibrarySection initialSection,
  }) => AppSheet.show<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * AppSheet.maxHeightFactor,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
        child: AssetsPage._sheet(initialSection: initialSection),
      ),
    ),
  );

  final bool _isSheet;
  final bool hasSampleContent;

  /// Allows previews to demonstrate the loading state.
  final bool isLoadingWorks;
  final AssetLibrarySection initialSection;
  final WorkLibraryRepository? repository;

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  late final WorkLibraryRepository _repository =
      widget.repository ??
      WorkLibraryRepository(NetworkApi(ref.read(dioProvider)));
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AssetLibrarySection _section;
  int _selectedFilter = 0;
  bool _selectingWorks = false;
  final Set<int> _selectedWorks = {};
  late List<_WorkGroup> _workGroups;
  final _scroll = ScrollController();
  List<LibraryWork> _works = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _deleting = false;
  Object? _error;
  int _page = 0;
  int _generation = 0;
  CancelToken? _requestToken;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _workGroups = widget.hasSampleContent
        ? _sampleWorkGroups
              .map((group) => _WorkGroup(group.date, List.of(group.items)))
              .toList()
        : [];
    _scroll.addListener(_nearBottom);
    ref.listenManual(userProvider.select((user) => user?.id), (_, __) {
      if (!widget.hasSampleContent) _refreshWorks(clear: true);
    });
    if (!widget.hasSampleContent && _section == AssetLibrarySection.works) {
      _refreshWorks();
    }
  }

  @override
  void dispose() {
    _generation++;
    _requestToken?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _nearBottom() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 200 &&
        _error == null) {
      _loadMoreWorks();
    }
  }

  Future<void> _refreshWorks({bool clear = false}) async {
    final generation = ++_generation;
    _requestToken?.cancel();
    final token = CancelToken();
    _requestToken = token;
    final authenticated = ref.read(userProvider) != null;
    setState(() {
      _loading = authenticated;
      _loadingMore = false;
      _error = null;
      _page = 0;
      _hasMore = false;
      _selectingWorks = false;
      _selectedWorks.clear();
      if (clear || !authenticated) {
        _works = [];
        _workGroups = [];
      }
    });
    if (!authenticated || _section != AssetLibrarySection.works) {
      setState(() => _loading = false);
      return;
    }
    await _fetchWorks(1, generation, token);
  }

  Future<void> _loadMoreWorks() async {
    if (_loading ||
        _loadingMore ||
        !_hasMore ||
        _selectingWorks ||
        _deleting ||
        widget.hasSampleContent ||
        _section != AssetLibrarySection.works) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    final token = CancelToken();
    _requestToken = token;
    await _fetchWorks(_page + 1, _generation, token);
  }

  Future<void> _fetchWorks(int page, int generation, CancelToken token) async {
    try {
      final result = await _repository.fetchPage(
        type: _selectedFilter,
        page: page,
        cancelToken: token,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _works = {
          if (page > 1)
            for (final work in _works) work.id: work,
          for (final work in result.items) work.id: work,
        }.values.toList();
        _workGroups = _groupWorks(_works);
        _page = page;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _nearBottom();
        });
      }
    }
  }

  List<_WorkGroup> _groupWorks(List<LibraryWork> works) {
    final sorted = List.of(works)
      ..sort(
        (a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          a.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      );
    final groups = <String, List<_WorkItem>>{};
    for (final work in sorted) {
      final date = work.createdAt;
      final label = date == null
          ? ''
          : '${date.year}.${date.month.toString().padLeft(2, '0')}.'
                '${date.day.toString().padLeft(2, '0')}';
      groups
          .putIfAbsent(label, () => [])
          .add(
            _WorkItem(
              work.previewUrl,
              id: work.id,
              isNetwork: true,
              isVideo: work.isVideo,
              videoUrl: work.videoUrl,
              selectionAsset: work.previewUrl,
            ),
          );
    }
    return [
      for (final group in groups.entries) _WorkGroup(group.key, group.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = widget._isSheet
        ? 12.0
        : math.max(MediaQuery.paddingOf(context).top, 52).toDouble();

    return Scaffold(
      key: _scaffoldKey,
      drawer: widget._isSheet ? null : const PopiNavigationDrawer(),
      backgroundColor:
          !widget._isSheet && Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF5F4FA)
          : Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        bottom: widget._isSheet,
        child: Column(
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
                hasWorks: _workGroups.any(
                  (group) => group.items.any(
                    (item) =>
                        _selectedFilter == 0 ||
                        (_selectedFilter == 2) == item.isVideo,
                  ),
                ),
                onSelected: _changeFilter,
                onToggleSelection: _toggleSelectionMode,
              ),
            ],
            if (_section == AssetLibrarySection.roles)
              const SizedBox(height: 16),
            Expanded(child: _buildSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildSection() {
    if (_section == AssetLibrarySection.roles) {
      return RoleLibraryList(
        category: _selectedFilter == 0 ? 'official' : 'personal',
      );
    }
    if ((widget.isLoadingWorks || _loading) &&
        !_workGroups.any((group) => group.items.isNotEmpty)) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: AppSkeletonGrid(
          key: const Key('assets-works-skeleton'),
          label: AppLocalizations.of(context)!.loadingAssets,
        ),
      );
    }
    final library = _WorksLibrary(
      groups: _workGroups,
      filter: _selectedFilter,
      selecting: _selectingWorks,
      selected: _selectedWorks,
      onToggle: _toggleWork,
      onPreview: _previewWork,
      onLongPress: (index) => setState(() {
        if (_loading || _loadingMore || _deleting) return;
        _selectingWorks = true;
        _selectedWorks.add(index);
      }),
      onDownload: _downloadSelected,
      onDelete: _deleteSelected,
      scrollController: _scroll,
      loadingMore: _loadingMore,
      error: _error,
      onRetry: () => _page == 0 ? _refreshWorks() : _loadMoreWorks(),
      actionsEnabled: !_deleting,
    );
    if (widget.hasSampleContent) return library;
    return RefreshIndicator(onRefresh: _refreshWorks, child: library);
  }

  void _changeFilter(int index) {
    if (index == _selectedFilter || _deleting) return;
    setState(() {
      _selectedFilter = index;
      _selectingWorks = false;
      _selectedWorks.clear();
    });
    if (_section == AssetLibrarySection.works && !widget.hasSampleContent) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _refreshWorks(clear: true);
    }
  }

  void _changeSection(AssetLibrarySection section) {
    if (_section == section || _deleting) return;
    setState(() {
      _section = section;
      _selectedFilter = 0;
      _selectingWorks = false;
      _selectedWorks.clear();
    });
    if (!widget.hasSampleContent) _refreshWorks(clear: true);
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
    if (_deleting || _loading || _loadingMore) return;
    setState(() {
      _selectingWorks = !_selectingWorks;
      _selectedWorks.clear();
    });
  }

  void _toggleWork(int index) {
    if (!_selectingWorks || _deleting) return;
    setState(() {
      if (!_selectedWorks.add(index)) _selectedWorks.remove(index);
    });
  }

  void _downloadSelected() {
    if (_selectedWorks.isEmpty) return;
    AppToast.info(
      context,
      AppLocalizations.of(context)!.assetDownloadUnavailable,
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedWorks.isEmpty || _deleting) return;
    final l10n = AppLocalizations.of(context)!;
    final generation = _generation;
    final selectedItems = _workGroups.expand((group) => group.items).toList();
    final selected = Set.of(_selectedWorks);
    final confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.deleteAssetsTitle,
      description: l10n.deleteAssetsDescription(_selectedWorks.length),
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.delete,
      confirmKey: const Key('confirm-delete-assets'),
      destructive: true,
    );
    if (confirmed != true || !mounted || generation != _generation) return;
    if (!widget.hasSampleContent) {
      setState(() => _deleting = true);
      final token = CancelToken();
      _requestToken?.cancel();
      _requestToken = token;
      try {
        for (final index in selected) {
          await _repository.delete(
            selectedItems[index].id!,
            cancelToken: token,
          );
        }
      } catch (_) {
        if (mounted && generation == _generation) {
          AppToast.error(context, l10n.networkRequestFailed);
        }
      } finally {
        if (mounted) {
          setState(() => _deleting = false);
          if (generation == _generation) await _refreshWorks();
        }
      }
      return;
    }
    var flatIndex = 0;
    final groups = <_WorkGroup>[];
    for (final group in _workGroups) {
      final kept = <_WorkItem>[];
      for (final item in group.items) {
        if (!selected.contains(flatIndex)) kept.add(item);
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
    if (item.isVideo && item.videoUrl.isNotEmpty) {
      AppVideoPreview.show(context: context, url: Uri.parse(item.videoUrl));
      return;
    }
    if (item.asset.isEmpty) return;
    AppImagePreview.show(
      context: context,
      image: item.image,
      heroTag: 'work-preview-$index',
    );
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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _LibraryTab(
                      label: l10n.assetLibrary,
                      selected: selected == AssetLibrarySection.works,
                      onTap: () => onSelected(AssetLibrarySection.works),
                    ),
                  ),
                  Expanded(
                    child: _LibraryTab(
                      label: l10n.roleLibrary,
                      selected: selected == AssetLibrarySection.roles,
                      onTap: () => onSelected(AssetLibrarySection.roles),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
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
    required this.hasWorks,
    required this.onSelected,
    required this.onToggleSelection,
  });

  final AssetLibrarySection section;
  final int selected;
  final bool selectingWorks;
  final bool hasWorks;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = switch (section) {
      AssetLibrarySection.works => [l10n.filterAll, l10n.images, l10n.videos],
      AssetLibrarySection.roles => [l10n.officialRoles, l10n.myRoles],
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
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.05)
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
                        fontSize: section == AssetLibrarySection.roles
                            ? 14
                            : 16,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (section == AssetLibrarySection.works && hasWorks)
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
                        child: const Icon(Icons.checklist, size: 22),
                      ),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _WorksEmptyState extends StatelessWidget {
  const _WorksEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              math.min(180, constraints.maxHeight / 4),
            ),
            child: Center(
              child: Column(
                key: const Key('assets-works-empty-state'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ExcludeSemantics(
                    child: SizedBox(
                      width: 55,
                      height: 62,
                      child: AppSvgIcon.asset('assets_works_empty'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.noWorks,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 25,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.noWorksDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 16,
                      height: 30 / 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 110),
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const Key('assets-go-generate'),
                        onPressed: () => context.go('/'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Text(
                          l10n.goGenerate,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 20 / 16,
                            fontWeight: FontWeight.w700,
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
    required this.scrollController,
    required this.loadingMore,
    required this.error,
    required this.onRetry,
    required this.actionsEnabled,
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
  final ScrollController scrollController;
  final bool loadingMore;
  final Object? error;
  final VoidCallback onRetry;
  final bool actionsEnabled;

  Widget _retry(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      key: const Key('assets-works-error'),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.networkRequestFailed, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      if (error != null || loadingMore) {
        return ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (error != null) _retry(context),
            if (loadingMore) const Center(child: CircularProgressIndicator()),
          ],
        );
      }
      // Keep a scroll position even when a page contains only unsupported media.
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: const _WorksEmptyState(),
            ),
          ],
        ),
      );
    }

    var offset = 0;
    final sections = <Widget>[];
    for (final group in groups) {
      final groupOffset = offset;
      final visible = [
        for (var i = 0; i < group.items.length; i++)
          if (filter == 0 || (filter == 2) == group.items[i].isVideo) i,
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
              heroTag: 'work-preview-$globalIndex',
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

    if (sections.isEmpty) {
      return const _WorksEmptyState();
    }
    if (loadingMore) {
      sections.add(const Center(child: CircularProgressIndicator()));
    }
    if (error != null) sections.add(_retry(context));

    return Stack(
      children: [
        ListView(
          key: const Key('assets-works-grid'),
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 10, 20, selecting ? 120 : 20),
          children: sections,
        ),
        if (selecting)
          Align(
            alignment: Alignment.bottomCenter,
            child: _SelectionActions(
              hasSelection: selected.isNotEmpty && actionsEnabled,
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
    required this.heroTag,
    required this.selecting,
    required this.selectionNumber,
    required this.onTap,
    required this.onLongPress,
  });

  final _WorkItem item;
  final String heroTag;
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
            Hero(
              tag: heroTag,
              child: item.asset.isEmpty
                  ? const ColoredBox(
                      color: AppColors.surfaceTint,
                      child: Icon(Icons.videocam_outlined),
                    )
                  : Image(
                      image: item.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.surfaceTint,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            if (item.isNetwork && item.isVideo)
              const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            l10n.selectedAssets(selectionCount),
            style: Theme.of(context).textTheme.labelMedium,
          ),
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
            ),
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
    this.id,
    this.isNetwork = false,
    this.videoUrl = '',
  });

  final String asset;
  final String selectionAsset;
  final bool isVideo;
  final String? id;
  final bool isNetwork;
  final String videoUrl;
  ImageProvider get image =>
      isNetwork ? NetworkImage(asset) : AssetImage(asset);
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
