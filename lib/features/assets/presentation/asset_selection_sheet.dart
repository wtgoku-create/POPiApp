import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../role_guide/presentation/widgets/role_guide_controls.dart';
import '../../role_guide/presentation/widgets/role_guide_sheet.dart';
import '../data/work_library_repository.dart';
import '../domain/library_work.dart';
import 'library_work_thumbnail.dart';

/// Selects existing image/video works without changing the asset library.
class AssetSelectionSheet extends ConsumerStatefulWidget {
  const AssetSelectionSheet({
    this.selected = const [],
    this.limit = 5,
    this.repository,
    super.key,
  });

  final List<LibraryWork> selected;
  final int limit;
  final WorkLibraryRepository? repository;

  static Future<List<LibraryWork>?> show({
    required BuildContext context,
    List<LibraryWork> selected = const [],
    int limit = 5,
    WorkLibraryRepository? repository,
  }) => AppSheet.show<List<LibraryWork>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => AssetSelectionSheet(
      selected: selected,
      limit: limit,
      repository: repository,
    ),
  );

  @override
  ConsumerState<AssetSelectionSheet> createState() =>
      _AssetSelectionSheetState();
}

class _AssetSelectionSheetState extends ConsumerState<AssetSelectionSheet> {
  late final _repository =
      widget.repository ??
      WorkLibraryRepository(NetworkApi(ref.read(dioProvider)));
  late final _selected = widget.selected.toList();
  final _works = <LibraryWork>[];
  ScrollController? _scroll;
  CancelToken? _token;
  int _filter = 0;
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    ref.listenManual(userProvider.select((user) => user?.id), (_, __) {
      _selected.clear();
      _reload();
    });
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _token?.cancel();
    _scroll?.removeListener(_nearBottom);
    super.dispose();
  }

  void _bindScroll(ScrollController controller) {
    if (identical(_scroll, controller)) return;
    _scroll?.removeListener(_nearBottom);
    _scroll = controller..addListener(_nearBottom);
  }

  void _nearBottom() {
    if (_scroll?.hasClients == true &&
        _scroll!.position.extentAfter < 200 &&
        !_failed) {
      _load();
    }
  }

  void _reload() {
    _generation++;
    _token?.cancel();
    setState(() {
      _works.clear();
      _page = 0;
      _loading = false;
      _failed = false;
      _hasMore = true;
    });
    if (_scroll?.hasClients == true) _scroll!.jumpTo(0);
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore || ref.read(userProvider) == null) return;
    final generation = _generation;
    final token = CancelToken();
    _token = token;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await _repository.fetchPage(
        type: _filter,
        page: _page + 1,
        cancelToken: token,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = _works.map((work) => work.id).toSet();
        _works.addAll(result.items.where((work) => ids.add(work.id)));
        _page++;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _nearBottom();
        });
      }
    }
  }

  void _toggle(LibraryWork work) {
    final index = _selected.indexWhere((item) => item.id == work.id);
    if (index >= 0) {
      setState(() => _selected.removeAt(index));
    } else if (_selected.length < widget.limit) {
      setState(() => _selected.add(work));
    } else {
      AppToast.info(
        context,
        AppLocalizations.of(context)!.assetSelectionLimit(widget.limit),
      );
    }
  }

  Widget _library(ScrollController controller) {
    _bindScroll(controller);
    final l10n = AppLocalizations.of(context)!;
    final groups = <String, List<LibraryWork>>{};
    final sorted = _works.indexed.toList()
      ..sort((a, b) {
        final date = (b.$2.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          a.$2.createdAt?.millisecondsSinceEpoch ?? 0,
        );
        return date != 0 ? date : a.$1.compareTo(b.$1);
      });
    for (final entry in sorted) {
      final work = entry.$2;
      final date = work.createdAt;
      final label = date == null
          ? ''
          : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(label, () => []).add(work);
    }
    return CustomScrollView(
      key: const Key('asset-selection-scroll'),
      controller: controller,
      slivers: [
        for (final group in groups.entries) ...[
          if (group.key.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Text(
                  group.key,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: group.value.length,
              itemBuilder: (context, index) {
                final work = group.value[index];
                final order =
                    _selected.indexWhere((item) => item.id == work.id) + 1;
                return Semantics(
                  button: true,
                  selected: order > 0,
                  label:
                      '${work.isVideo ? l10n.videos : l10n.images} ${work.id}',
                  child: GestureDetector(
                    key: ValueKey('asset-library-select-${work.id}'),
                    onTap: () => _toggle(work),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LibraryWorkThumbnail(work: work),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: RoleSelectionBadge(order: order),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _loading
                ? AppSkeleton(
                    label: l10n.loadingAssets,
                    child: const AppSkeletonBox(height: 100),
                  )
                : _failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.networkRequestFailed),
                      TextButton(
                        key: const Key('asset-selection-retry'),
                        onPressed: _load,
                        child: Text(l10n.retry),
                      ),
                    ],
                  )
                : _works.isEmpty
                ? Text(l10n.noWorks, textAlign: TextAlign.center)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: RoleGuideSheet(
          key: const Key('asset-selection-sheet'),
          title: l10n.assetLibrary,
          initialSize: AppSheet.maxHeightFactor,
          header: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              l10n.assetLibrary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: .9),
          builder: (_, controller) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RoleGuideSegments(
                  labels: [l10n.filterAll, l10n.images, l10n.videos],
                  selected: _filter,
                  filledTrack: false,
                  scrollable: true,
                  onSelected: (filter) {
                    if (_filter == filter) return;
                    _filter = filter;
                    _reload();
                  },
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _library(controller)),
            ],
          ),
          footer: RoleGuideAction(
            key: const Key('asset-selection-confirm'),
            label: l10n.roleConfirmSelection,
            showArrow: false,
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(List<LibraryWork>.unmodifiable(_selected)),
          ),
        ),
      ),
    );
  }
}
