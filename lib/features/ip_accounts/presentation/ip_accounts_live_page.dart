import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/controllers/paged_list_controller.dart';
import '../../../shared/widgets/app_paged_scroll.dart';
import '../../../shared/providers/ip_account_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/providers/project_provider.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../domain/ip_account.dart';
import 'ip_accounts_page.dart';

/// Loads account rows on entry and refreshes them when returning from details.
class IpAccountsLivePage extends ConsumerStatefulWidget {
  const IpAccountsLivePage({super.key});

  @override
  ConsumerState<IpAccountsLivePage> createState() => _IpAccountsLivePageState();
}

class _IpAccountsLivePageState extends ConsumerState<IpAccountsLivePage> {
  late PagedListController<IpAccount> _pages;
  List<IpAccount> get _accounts => _pages.items;
  bool get _loading => _pages.loading;
  CancelToken? _deleteToken;
  String? _deletingAccountId;

  Future<void> _delete(IpAccount account) async {
    final owner = ref.read(userProvider)?.id;
    if (owner == null || _loading || _deleteToken != null) return;
    final token = CancelToken();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _deleteToken = token);
    try {
      final confirmed = await AppDialog.confirm(
        context: context,
        title: l10n.deleteIpAccountTitle,
        useRootNavigator: true,
        description: l10n.deleteIpAccountDescription,
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.delete,
        confirmKey: const Key('confirm-delete-ip-account'),
        destructive: true,
      );
      if (confirmed != true ||
          !mounted ||
          token.isCancelled ||
          ref.read(userProvider)?.id != owner) {
        return;
      }
      setState(() => _deletingAccountId = account.id);
      await ref
          .read(ipAccountRepositoryProvider)
          .archive(account.id, cancelToken: token);
      if (!mounted ||
          token.isCancelled ||
          ref.read(userProvider)?.id != owner) {
        return;
      }
      _pages.remove(account.id);
      ref.invalidate(projectsProvider);
    } catch (_) {
      if (mounted &&
          !token.isCancelled &&
          ref.read(userProvider)?.id == owner) {
        AppToast.error(context, l10n.networkRequestFailed);
      }
    } finally {
      if (mounted && identical(_deleteToken, token)) {
        setState(() {
          _deleteToken = null;
          _deletingAccountId = null;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initPages();
    unawaited(_load());
  }

  void _initPages() {
    _pages = PagedListController(
      itemId: (item) => item.id,
      fetch: (page, token) => ref
          .read(ipAccountRepositoryProvider)
          .list(status: 'active', page: page, cancelToken: token),
    )..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pages.dispose();
    _deleteToken?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (ref.read(userProvider) == null || _deleteToken != null) return;
    final owner = ref.read(userProvider)?.id;
    try {
      await _pages.load(reset: reset);
    } catch (_) {
      if (mounted && ref.read(userProvider)?.id == owner) {
        AppToast.error(
          context,
          AppLocalizations.of(context)!.ipAccountLoadFailed,
        );
      }
      if (!reset) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, _) {
      _deleteToken?.cancel();
      _deleteToken = null;
      _deletingAccountId = null;
      _pages.dispose();
      _initPages();
      unawaited(_load());
    });
    return AppPagedScroll(
      onLoad: () => _load(reset: false),
      child: RefreshIndicator(
        onRefresh: () async {
          if (_deleteToken == null) await _load();
        },
        child: IpAccountsPage(
          accounts: _accounts,
          isLoading: _loading && _accounts.isEmpty,
          isLoadingMore: _loading && _accounts.isNotEmpty,
          hasMore: ref.watch(userProvider) != null && _pages.hasMore,
          onDeleteAccount: _loading ? null : _delete,
          isDeleting: _deleteToken != null,
          deletingAccountId: _deletingAccountId,
          onOpenAccount: (account) async {
            await context.push(
              '/ip-accounts/${Uri.encodeComponent(account.id)}',
            );
            if (mounted) await _load();
          },
        ),
      ),
    );
  }
}
