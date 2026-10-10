import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/widgets/app_image_preview.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../data/teaching_repository.dart';
import '../domain/teaching.dart';
import 'widgets/teaching_banners.dart';
import 'widgets/teaching_course_card.dart';

class TeachingPage extends ConsumerStatefulWidget {
  const TeachingPage({this.repository, super.key});

  final TeachingRepository? repository;

  @override
  ConsumerState<TeachingPage> createState() => _TeachingPageState();
}

class _TeachingPageState extends ConsumerState<TeachingPage> {
  static const _pageSize = 20;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  late final TeachingRepository _repository;
  List<TeachingCategory> _categories = const [];
  final List<TeachingCourse> _courses = [];
  TeachingHighlights _highlights = const TeachingHighlights();
  int? _categoryId;
  int _nextPage = 1;
  int _requestVersion = 0;
  int _categoriesVersion = 0;
  int _highlightsVersion = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _categoryFailed = false;
  bool _coursesFailed = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        TeachingRepository(NetworkApi(ref.read(dioProvider)));
    _scroll.addListener(_onScroll);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadCategories(),
      _loadHighlights(),
      _loadCourses(reset: true),
    ]);
  }

  Future<void> _loadCategories() async {
    final version = ++_categoriesVersion;
    try {
      final categories = await _repository.fetchCategories();
      if (!mounted || version != _categoriesVersion) return;
      setState(() {
        _categories = categories;
        _categoryFailed = false;
      });
      if (_categoryId != null &&
          !categories.any((category) => category.id == _categoryId)) {
        _selectCategory(null);
      }
    } catch (_) {
      if (mounted && version == _categoriesVersion) {
        setState(() => _categoryFailed = true);
      }
    }
  }

  Future<void> _loadHighlights() async {
    final version = ++_highlightsVersion;
    try {
      final highlights = await _repository.fetchHighlights();
      if (mounted && version == _highlightsVersion) {
        setState(() => _highlights = highlights);
      }
    } catch (_) {
      // Keep the catalog usable when supplementary content is unavailable.
    }
  }

  void _selectCategory(int? id) {
    if (id == _categoryId) return;
    setState(() => _categoryId = id);
    unawaited(_loadCourses(reset: true));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 240) {
      unawaited(_loadCourses());
    }
  }

  Future<void> _loadCourses({bool reset = false}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore || _coursesFailed)) {
      return;
    }
    final version = reset ? ++_requestVersion : _requestVersion;
    final page = reset ? 1 : _nextPage;
    final categoryId = _categoryId;
    setState(() {
      _coursesFailed = false;
      if (reset) {
        _loading = true;
        _loadingMore = false;
        _courses.clear();
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await _repository.fetchCourses(
        page: page,
        pageSize: _pageSize,
        categoryId: categoryId,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        final ids = _courses.map((course) => course.id).toSet();
        _courses.addAll(result.items.where((course) => ids.add(course.id)));
        _nextPage = page + 1;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onScroll();
      });
    } catch (_) {
      if (mounted && version == _requestVersion) {
        setState(() {
          _coursesFailed = true;
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _retryCourses() {
    setState(() => _coursesFailed = false);
    unawaited(_loadCourses(reset: _courses.isEmpty));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF5F4FA)
        : scheme.surface;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: background,
      drawer: const PopiNavigationDrawer(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(height: math.max(52, MediaQuery.paddingOf(context).top)),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Text(
                      l10n.teachingCenter,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTypeSizes.pageTitle,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 15,
                    child: IconButton(
                      key: const Key('popi-open-navigation'),
                      tooltip: l10n.openNavigation,
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      icon: AppSvgIcon.asset(
                        'common_navigation_menu',
                        size: 30,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  key: const Key('teaching-scroll'),
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        child: TeachingBanners(
                          highlights: _highlights,
                          onMembership: () =>
                              context.push('/profile/membership'),
                          onCommunity: _highlights.communityQrUrl.isEmpty
                              ? null
                              : () => AppImagePreview.show(
                                  context: context,
                                  image: NetworkImage(
                                    _highlights.communityQrUrl,
                                  ),
                                  heroTag: 'teaching-community-qr',
                                  label: l10n.teachingCommunityTitle,
                                ),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _CategoryHeader(
                        background: background,
                        extent: math.max(
                          56,
                          MediaQuery.textScalerOf(context).scale(14) * 1.3 + 36,
                        ),
                        child: _CategoryFilters(
                          categories: _categories,
                          selected: _categoryId,
                          onSelected: _selectCategory,
                        ),
                      ),
                    ),
                    if (_categoryFailed)
                      SliverToBoxAdapter(
                        child: Center(
                          child: TextButton.icon(
                            key: const Key('teaching-retry-categories'),
                            onPressed: _loadCategories,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(l10n.teachingCategoriesFailed),
                          ),
                        ),
                      ),
                    if (_loading || _courses.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _CourseStatus(
                          loading: _loading,
                          failed: _coursesFailed,
                          onRetry: _retryCourses,
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.crossAxisExtent;
                            final columns = width < 680
                                ? 2
                                : math.min(4, (width / 240).floor());
                            final cardWidth =
                                (width - 10 * (columns - 1)) / columns;
                            final scaler = MediaQuery.textScalerOf(context);
                            final infoHeight =
                                (25 +
                                        math.max(40, scaler.scale(14) * 2.8) +
                                        math.max(20, scaler.scale(12) + 8))
                                    .ceilToDouble();
                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    mainAxisExtent: cardWidth + infoHeight,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final course = _courses[index];
                                return TeachingCourseCard(
                                  key: ValueKey('teaching-course-${course.id}'),
                                  course: course,
                                  memberLabels: _highlights.memberLabels,
                                  onTap: () => context.push(
                                    '/teaching/document/${course.id}',
                                    extra: course,
                                  ),
                                );
                              }, childCount: _courses.length),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: _loadingMore
                              ? const Center(
                                  child: SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _coursesFailed
                              ? Center(
                                  child: TextButton.icon(
                                    key: const Key('teaching-retry-more'),
                                    onPressed: _retryCourses,
                                    icon: const Icon(Icons.refresh),
                                    label: Text(l10n.teachingLoadMoreFailed),
                                  ),
                                )
                              : const SizedBox(height: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<TeachingCategory> categories;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const Key('teaching-categories'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final (id, label) in [
            (null, l10n.teachingAll),
            ...categories.map((category) => (category.id, category.name)),
          ]) ...[
            Semantics(
              selected: selected == id,
              child: TextButton(
                key: ValueKey('teaching-category-${id ?? 'all'}'),
                onPressed: () => onSelected(id),
                style: TextButton.styleFrom(
                  minimumSize: const Size(76, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: selected == id
                      ? AppColors.brand.withValues(alpha: .05)
                      : Colors.transparent,
                  foregroundColor: selected == id
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0,
                    fontWeight: selected == id
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

class _CategoryHeader extends SliverPersistentHeaderDelegate {
  const _CategoryHeader({
    required this.background,
    required this.child,
    required this.extent,
  });

  final Color background;
  final Widget child;
  final double extent;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: background,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(_CategoryHeader oldDelegate) =>
      background != oldDelegate.background ||
      extent != oldDelegate.extent ||
      child != oldDelegate.child;
}

class _CourseStatus extends StatelessWidget {
  const _CourseStatus({
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: loading
            ? SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: l10n.teachingLoading,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    failed ? Icons.cloud_off_outlined : Icons.school_outlined,
                    size: 32,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    failed ? l10n.teachingLoadFailed : l10n.teachingEmpty,
                    textAlign: TextAlign.center,
                  ),
                  if (failed) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      key: const Key('teaching-retry-courses'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
