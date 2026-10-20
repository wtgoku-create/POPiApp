import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/ip_account_provider.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/type/list_page.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../session/domain/session_artifact.dart';
import '../../session/presentation/widgets/session_artifacts_sheet.dart';
import 'widgets/ip_account_history.dart';

/// Searchable account history with local loading and refresh state.
class IpAccountHistoryPage extends ConsumerStatefulWidget {
  const IpAccountHistoryPage({required this.accountId, super.key});

  final String accountId;

  @override
  ConsumerState<IpAccountHistoryPage> createState() =>
      _IpAccountHistoryPageState();
}

class _IpAccountHistoryPageState extends ConsumerState<IpAccountHistoryPage> {
  final _search = TextEditingController();
  CancelToken? _token;
  Timer? _debounce;
  final _creations = <SessionArtifact>[];
  ListPage<SessionArtifact>? _page;
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(IpAccountHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _debounce?.cancel();
      _search.clear();
      _query = '';
      _creations.clear();
      _page = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _token?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && _loading) return;
    _debounce?.cancel();
    _token?.cancel();
    final token = _token = CancelToken();
    setState(() {
      _loading = true;
    });
    if (ref.read(userProvider) == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final page = await ref
          .read(ipAccountRepositoryProvider)
          .creationHistory(
            widget.accountId,
            keyword: _query.trim(),
            page: more ? (_page?.page ?? 0) + 1 : 1,
            cancelToken: token,
          );
      if (!mounted || token.isCancelled) return;
      setState(() {
        final items = <String, SessionArtifact>{
          if (more)
            for (final item in _creations) item.id: item,
          for (final item in page.items) item.id: item,
        };
        _creations
          ..clear()
          ..addAll(items.values);
        _page = page;
      });
    } catch (_) {
      if (mounted && !token.isCancelled) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.creationHistoryLoadFailed,
        );
      }
    } finally {
      if (mounted && !token.isCancelled) setState(() => _loading = false);
    }
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _token?.cancel();
    setState(() {
      _query = value;
      _creations.clear();
      _page = null;
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () => _load());
  }

  Future<void> _open(SessionArtifact creation) async {
    final token = _token;
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SessionArtifactDetailPage(item: creation),
      ),
    );
    if (mounted && token != null && !token.isCancelled) await _load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, _) {
      _debounce?.cancel();
      _token?.cancel();
      _search.clear();
      setState(() {
        _creations.clear();
        _page = null;
        _query = '';
      });
      context.go('/ip-accounts');
    });
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final insets = ref.watch(safeAreaInsetsProvider);
    final guest = ref.watch(userProvider) == null;
    final hasMore = _page != null && _page!.page < _page!.pageCount;
    final sidePadding =
        20.0 + math.max(0.0, (MediaQuery.sizeOf(context).width - 640) / 2);

    return Scaffold(
      backgroundColor: colors.brightness == Brightness.light
          ? const Color(0xFFF5F4FA)
          : colors.surface,
      body: Column(
        children: [
          SizedBox(
            height: math.max(
              52,
              math.max(insets.top, MediaQuery.viewPaddingOf(context).top),
            ),
          ),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 15),
                SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    key: const Key('ip-account-history-back'),
                    tooltip: l10n.back,
                    padding: EdgeInsets.zero,
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/ip-accounts'),
                    icon: RotatedBox(
                      quarterTurns: 1,
                      child: AppSvgIcon.asset(
                        'ip_guide_back',
                        size: 40,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.creationHistory,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          if (!guest)
            Padding(
              padding: EdgeInsets.fromLTRB(sidePadding, 10, sidePadding, 10),
              child: TextField(
                key: const Key('ip-account-history-search'),
                controller: _search,
                onChanged: _searchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  FocusScope.of(context).unfocus();
                  unawaited(_load());
                },
                style: const TextStyle(fontSize: 14, height: 18 / 14),
                decoration: InputDecoration(
                  hintText: l10n.searchCreationHistory,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colors.brightness == Brightness.light
                      ? Colors.white
                      : colors.surfaceContainerHigh,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 36,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: AppSvgIcon.asset(
                      'ip_account_history_search',
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('ip-account-history-clear-search'),
                          tooltip: l10n.clearSearch,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          style: const ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            _search.clear();
                            _searchChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadii.pill),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadii.pill),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ),
            ),
          Expanded(
            child: guest
                ? Center(
                    child: FilledButton(
                      onPressed: () => context.push('/login'),
                      child: Text(l10n.goToLogin),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      key: const Key('ip-account-history-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        sidePadding,
                        0,
                        sidePadding,
                        math.max(20, insets.bottom),
                      ),
                      itemCount: _creations.isEmpty
                          ? 1
                          : _creations.length + ((_loading || hasMore) ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (_loading && index == _creations.length) {
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (_creations.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              _query.trim().isEmpty
                                  ? l10n.noHistory
                                  : l10n.noMatchingHistory,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        if (index == _creations.length) {
                          return TextButton(
                            key: const Key('ip-account-history-load-more'),
                            onPressed: () => _load(more: true),
                            child: Text(l10n.accountLoadMore),
                          );
                        }
                        final creation = _creations[index];
                        return Material(
                          key: ValueKey(creation.id),
                          color: colors.brightness == Brightness.light
                              ? Colors.white.withValues(alpha: .5)
                              : colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: IpAccountHistoryRow(
                              creation: creation,
                              arrowColor: colors.onSurfaceVariant,
                              onTap: () => _open(creation),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
