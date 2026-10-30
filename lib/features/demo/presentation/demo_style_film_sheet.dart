import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/harness_access_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_toast.dart';
import '../domain/demo_style_film_models.dart';
import 'widgets/demo_widgets.dart';

typedef DemoStyleFilmCatalogLoader =
    Future<DemoStyleFilmCatalog> Function({
      required String query,
      String? category,
      required int page,
      required int pageSize,
    });

Future<DemoStyleFilmSelection?> showDemoStyleFilmSheet({
  required BuildContext context,
  required DemoStyleFilmCatalogLoader loadCatalog,
  DemoStyleFilmSelection? initialSelection,
}) => DemoSheet.show<DemoStyleFilmSelection>(
  context: context,
  builder: (_) => DemoStyleFilmSheet(
    loadCatalog: loadCatalog,
    initialSelection: initialSelection,
  ),
);

class DemoStyleFilmSheet extends StatefulWidget {
  const DemoStyleFilmSheet({
    required this.loadCatalog,
    this.initialSelection,
    super.key,
  });

  final DemoStyleFilmCatalogLoader loadCatalog;
  final DemoStyleFilmSelection? initialSelection;

  @override
  State<DemoStyleFilmSheet> createState() => _DemoStyleFilmSheetState();
}

class _DemoStyleFilmSheetState extends State<DemoStyleFilmSheet> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  final List<DemoStyleFilmStyle> _styles = [];
  Timer? _searchDebounce;
  DemoStyleFilmCatalog? _catalog;
  DemoStyleFilmSelection? _selection;
  String? _category;
  bool _loading = false;
  int _page = 0;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSelection;
    _scroll.addListener(_loadNextPage);
    _search.addListener(_scheduleSearch);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _scroll
      ..removeListener(_loadNextPage)
      ..dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => unawaited(_load(reset: true)),
    );
  }

  void _loadNextPage() {
    if (!_scroll.hasClients || _loading || _catalog == null) return;
    if (_page >= _catalog!.pageCount) return;
    if (_scroll.position.extentAfter < 420) unawaited(_load());
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final request = ++_request;
    if (reset) {
      _page = 0;
      _styles.clear();
    }
    setState(() {
      _loading = true;
    });
    try {
      final catalog = await widget.loadCatalog(
        query: _search.text.trim(),
        category: _category,
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _catalog = catalog;
        _page = catalog.page;
        final known = _styles.map((style) => style.id).toSet();
        _styles.addAll(catalog.list.where((style) => known.add(style.id)));
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _loading = false);
      AppToast.error(
        context,
        AppLocalizations.of(context)!.demoStyleFilmLoadFailed,
      );
    }
  }

  void _selectCategory(String? category) {
    if (_category == category) return;
    setState(() => _category = category);
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final supports = _catalog?.supports ?? const DemoStyleFilmSupports();
    final languageCode = Localizations.localeOf(context).languageCode;
    final categories = _catalog?.categories ?? const [];
    final noReadyStyles = _catalog != null && _catalog!.readyCount == 0;
    return DemoSheetBody(
      key: const Key('demo-style-film-sheet'),
      title: l.demoStyleFilmSheetTitle,
      uploadLayout: true,
      footer: _StyleFilmFooter(
        hint: noReadyStyles ? l.demoStyleFilmNoReadyFooter : null,
        child: DemoPrimaryButton(
          key: const Key('demo-style-film-confirm'),
          label: l.confirm,
          onPressed: _selection == null || !supports.accepts(_selection!)
              ? null
              : () => Navigator.of(context).pop(_selection),
        ),
      ),
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: TextField(
              key: const Key('demo-style-film-search'),
              controller: _search,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: l.demoStyleFilmSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = index == 0 ? null : categories[index - 1];
                  final id = category?.id;
                  return FilterChip(
                    key: ValueKey('demo-style-film-category-${id ?? 'all'}'),
                    selected: _category == id,
                    label: Text(
                      category != null
                          ? category.nameFor(languageCode)
                          : l.demoStyleFilmAllCategories,
                    ),
                    onSelected: (_) => _selectCategory(id),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_catalog != null)
            SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    l.demoStyleFilmStyleCount(_catalog!.total),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l.demoStyleFilmReadyCount(_catalog!.readyCount),
                    style: TextStyle(
                      fontSize: 12,
                      color: _catalog!.readyCount > 0
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          if (_catalog != null)
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (noReadyStyles)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_unavailableLabel(l, _catalog!.reasonUnavailableCode)} · '
                  '${l.demoStyleFilmBrowsePending}',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ),
          if (_styles.isEmpty && _loading)
            SliverToBoxAdapter(
              child: AppSkeleton(
                label: l.demoStyleFilmLoadingCatalog,
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppSkeletonBox(height: 190, radius: 18),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: AppSkeletonBox(height: 190, radius: 18),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppSkeletonBox(height: 190, radius: 18),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: AppSkeletonBox(height: 190, radius: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (_styles.isEmpty && !_loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(l.demoStyleFilmNoReadyStyles)),
            )
          else
            SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 760 ? 3 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 190,
              ),
              itemCount: _styles.length,
              itemBuilder: (context, index) {
                final style = _styles[index];
                return _StyleCard(
                  style: style,
                  selected: _selection?.styleId == style.id,
                  onSelected: style.ready
                      ? () => setState(() {
                          final current = _selection;
                          _selection = DemoStyleFilmSelection(
                            styleId: style.id,
                            styleNameZh: style.nameZh,
                            styleNameEn: style.nameEn,
                            durationSeconds:
                                current?.durationSeconds ??
                                supports.durations.firstOrNull ??
                                15,
                            aspectRatio:
                                current?.aspectRatio ??
                                supports.aspectRatios.firstOrNull ??
                                '9:16',
                            soundtrack:
                                current?.soundtrack ??
                                supports.soundtracks.firstOrNull ??
                                'none',
                          );
                        })
                      : null,
                );
              },
            ),
          if (_selection != null) ...[
            SliverToBoxAdapter(
              child: _SelectionOptions(
                selection: _selection!,
                supports: supports,
                onChanged: (selection) =>
                    setState(() => _selection = selection),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: SizedBox(
              key: const Key('demo-style-film-bottom-spacer'),
              height: noReadyStyles
                  ? 180
                  : _selection == null
                  ? 132
                  : 144,
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 86),
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StyleFilmFooter extends StatelessWidget {
  const _StyleFilmFooter({required this.child, this.hint});

  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('demo-style-film-footer'),
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hint != null) ...[
          Text(
            hint!,
            key: const Key('demo-style-film-footer-hint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        child,
      ],
    ),
  );
}

String _unavailableLabel(AppLocalizations l, String code) => switch (code) {
  'unsupported_style' => l.demoStyleFilmReasonUnsupportedStyle,
  'unverified_style' => l.demoStyleFilmReasonUnverifiedStyle,
  'runtime_unavailable' => l.demoStyleFilmReasonRuntimeUnavailable,
  'model_unavailable' => l.demoStyleFilmReasonModelUnavailable,
  _ => l.demoStyleFilmReasonUnknown,
};

class _StyleCard extends ConsumerWidget {
  const _StyleCard({
    required this.style,
    required this.selected,
    required this.onSelected,
  });

  final DemoStyleFilmStyle style;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final url = style.posterUrl;
    return Semantics(
      selected: selected,
      button: onSelected != null,
      child: Material(
        key: ValueKey('demo-style-film-style-${style.id}'),
        color: demoSurface(context),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? AppColors.brand : Colors.transparent,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: url.isEmpty
                    ? ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.palette_outlined),
                      )
                    : AppNetworkImage(
                        url,
                        fit: BoxFit.cover,
                        semanticLabel: l.demoStyleFilmPosterLabel(
                          style.nameFor(languageCode),
                        ),
                        headers: ref.watch(harnessAccessHeadersProvider(url)),
                        cacheKey: ref.watch(harnessAccessCacheKeyProvider(url)),
                        onUnauthorized: ref.watch(
                          harnessAccessUnauthorizedProvider(url),
                        ),
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : ColoredBox(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.nameFor(languageCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      style.ready
                          ? languageCode == 'zh'
                                ? style.descriptionZh
                                : style.descriptionEn
                          : _unavailableLabel(l, style.reasonUnavailableCode),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionOptions extends StatelessWidget {
  const _SelectionOptions({
    required this.selection,
    required this.supports,
    required this.onChanged,
  });

  final DemoStyleFilmSelection selection;
  final DemoStyleFilmSupports supports;
  final ValueChanged<DemoStyleFilmSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    Widget choices<T>({
      required String label,
      required List<T> values,
      required T selected,
      required String Function(T) display,
      required ValueChanged<T> select,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              ChoiceChip(
                selected: selected == value,
                label: Text(display(value)),
                onSelected: (_) => select(value),
              ),
          ],
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          choices<int>(
            label: l.demoStyleFilmDuration,
            values: supports.durations,
            selected: selection.durationSeconds,
            display: (seconds) => '$seconds s',
            select: (seconds) =>
                onChanged(selection.copyWith(durationSeconds: seconds)),
          ),
          const SizedBox(height: 14),
          choices<String>(
            label: l.demoStyleFilmAspectRatio,
            values: supports.aspectRatios,
            selected: selection.aspectRatio,
            display: (ratio) => ratio,
            select: (ratio) =>
                onChanged(selection.copyWith(aspectRatio: ratio)),
          ),
          if (supports.soundtracks.isNotEmpty) ...[
            const SizedBox(height: 14),
            choices<String>(
              label: l.demoStyleFilmSoundtrack,
              values: supports.soundtracks,
              selected: selection.soundtrack,
              display: (soundtrack) => soundtrack == 'music'
                  ? l.demoStyleFilmSoundMusic
                  : l.demoStyleFilmSoundNone,
              select: (soundtrack) =>
                  onChanged(selection.copyWith(soundtrack: soundtrack)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.view_carousel_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(l.demoStyleFilmStoryboardReview)),
              const Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}
