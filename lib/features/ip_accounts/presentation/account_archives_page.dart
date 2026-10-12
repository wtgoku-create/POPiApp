import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/ip_account_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_menu.dart';
import '../domain/account_preferences.dart';
import '../domain/ip_account_home.dart';

/// Searchable account-scoped archives with local pagination and retry state.
class AccountArchivesPage extends ConsumerStatefulWidget {
  const AccountArchivesPage({required this.accountId, super.key});
  final String accountId;
  @override
  ConsumerState<AccountArchivesPage> createState() =>
      _AccountArchivesPageState();
}

class _AccountArchivesPageState extends ConsumerState<AccountArchivesPage> {
  final _search = TextEditingController();
  final _items = <IpAccountCreation>[];
  AccountArchivePage? _page;
  CancelToken? _token;
  Timer? _debounce;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
    _token?.cancel();
    final token = _token = CancelToken();
    setState(() {
      _loading = true;
      _failed = false;
      if (!more) {
        _items.clear();
        _page = null;
      }
    });
    if (ref.read(userProvider) == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final page = await ref
          .read(ipAccountRepositoryProvider)
          .archives(
            widget.accountId,
            keyword: _search.text.trim(),
            page: more ? (_page?.page ?? 0) + 1 : 1,
            cancelToken: token,
          );
      if (mounted && !token.isCancelled) {
        setState(() {
          _items.addAll(page.items);
          _page = page;
        });
      }
    } catch (_) {
      if (mounted && !token.isCancelled) setState(() => _failed = true);
    } finally {
      if (mounted && !token.isCancelled) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((u) => u?.id), (_, _) {
      _debounce?.cancel();
      _token?.cancel();
      setState(() {
        _items.clear();
        _page = null;
      });
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountArchives)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('account-archive-search'),
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.accountArchiveSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                // Invalidate the old search immediately, before the debounce expires.
                _token?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _load(),
                );
              },
              onSubmitted: (_) {
                _debounce?.cancel();
                _load();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_loading && _items.isEmpty)
                    const Center(child: CircularProgressIndicator()),
                  if (!_loading && !_failed && _items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.ipAccountNoAssets,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final item in _items)
                    ListTile(
                      key: ValueKey('archive-${item.id}'),
                      leading: const Icon(Icons.movie_outlined),
                      title: Text(item.title),
                      subtitle: item.summary.isEmpty
                          ? null
                          : Text(
                              item.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AccountArchiveDetailPage(
                            accountId: widget.accountId,
                            creationId: item.id,
                            versionId: item.versionId,
                          ),
                        ),
                      ),
                    ),
                  if (_failed)
                    Column(
                      children: [
                        Text(l10n.networkRequestFailed),
                        TextButton(
                          onPressed: () => _load(more: _items.isNotEmpty),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  if (!_failed &&
                      _page != null &&
                      _page!.page < _page!.pageCount)
                    TextButton(
                      onPressed: _loading ? null : () => _load(more: true),
                      child: Text(l10n.accountLoadMore),
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

/// Frozen script, cast and generation inputs for a selected archive version.
class AccountArchiveDetailPage extends ConsumerStatefulWidget {
  const AccountArchiveDetailPage({
    required this.accountId,
    required this.creationId,
    this.versionId,
    super.key,
  });
  final String accountId;
  final String creationId;
  final String? versionId;
  @override
  ConsumerState<AccountArchiveDetailPage> createState() =>
      _AccountArchiveDetailPageState();
}

class _AccountArchiveDetailPageState
    extends ConsumerState<AccountArchiveDetailPage> {
  CancelToken? _token;
  AccountCreationArchive? _archive;
  bool _failed = false;
  late String? _version = widget.versionId;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _token?.cancel();
    final token = _token = CancelToken();
    setState(() {
      _archive = null;
      _failed = false;
    });
    if (ref.read(userProvider) == null) return;
    try {
      final archive = await ref
          .read(ipAccountRepositoryProvider)
          .archiveDetail(
            widget.accountId,
            widget.creationId,
            versionId: _version,
            cancelToken: token,
          );
      if (mounted && !token.isCancelled) {
        setState(() {
          _archive = archive;
          _version = archive.versionId;
        });
      }
    } catch (_) {
      if (mounted && !token.isCancelled) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((u) => u?.id), (_, _) {
      _token?.cancel();
      setState(() => _archive = null);
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
    final l10n = AppLocalizations.of(context)!;
    final archive = _archive;
    final labels = {
      'summary': l10n.accountArchiveSummary,
      'brief': l10n.accountArchiveBrief,
      'topic': l10n.accountArchiveTopic,
      'script': l10n.accountArchiveScript,
      'storyboard': l10n.accountArchiveStoryboard,
      'cast': l10n.accountArchiveCast,
      'generation': l10n.accountArchiveGeneration,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(archive?.title ?? l10n.accountArchives),
        actions: [
          if (archive != null && archive.versions.length > 1)
            AppMenuButton(
              tooltip: l10n.accountArchiveVersion,
              icon: const Icon(Icons.history),
              entries: [
                for (final version in archive.versions.entries)
                  AppMenuItem(
                    label: '${l10n.accountArchiveVersion} ${version.value}',
                    selected: _version == version.key,
                    onSelected: () {
                      _version = version.key;
                      _load();
                    },
                  ),
              ],
            ),
        ],
      ),
      body: archive == null
          ? Center(
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.networkRequestFailed),
                        TextButton(onPressed: _load, child: Text(l10n.retry)),
                      ],
                    )
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final entry in archive.sections.entries) ...[
                  Text(
                    labels[entry.key]!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: entry.value.isEmpty
                        ? l10n.ipAccountFieldEmpty
                        : entry.value,
                    selectable: true,
                  ),
                  const Divider(height: 32),
                ],
                if (archive.sessionId?.isNotEmpty == true)
                  TextButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(l10n.accountOpenConversation),
                    onPressed: () => context.push(
                      Uri(
                        path: '/session',
                        queryParameters: {'sessionId': archive.sessionId!},
                      ).toString(),
                    ),
                  ),
              ],
            ),
    );
  }
}
