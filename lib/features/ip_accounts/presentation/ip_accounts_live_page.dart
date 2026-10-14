import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
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
  List<IpAccount> _accounts = const [];
  bool _loading = true;
  bool _failed = false;
  CancelToken? _token;
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
      setState(
        () => _accounts = [
          for (final item in _accounts)
            if (item.id != account.id) item,
        ],
      );
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
    unawaited(_load());
  }

  @override
  void dispose() {
    _token?.cancel();
    _deleteToken?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _token?.cancel();
    final token = _token = CancelToken();
    setState(() {
      _loading = true;
      _failed = false;
    });
    if (ref.read(userProvider) == null) {
      setState(() {
        _accounts = [];
        _loading = false;
      });
      return;
    }
    try {
      final accounts = await ref
          .read(ipAccountRepositoryProvider)
          .list(status: 'active', cancelToken: token);
      if (mounted && !token.isCancelled) setState(() => _accounts = accounts);
    } catch (_) {
      if (mounted && !token.isCancelled) setState(() => _failed = true);
    } finally {
      if (mounted && !token.isCancelled) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider.select((user) => user?.id), (_, _) {
      _deleteToken?.cancel();
      _deleteToken = null;
      _deletingAccountId = null;
      _accounts = const [];
      unawaited(_load());
    });
    return RefreshIndicator(
      onRefresh: () async {
        if (_deleteToken == null) await _load();
      },
      child: IpAccountsPage(
        accounts: _accounts,
        isLoading: _loading,
        onRetry: _failed ? _load : null,
        onDeleteAccount: _delete,
        isDeleting: _deleteToken != null,
        deletingAccountId: _deletingAccountId,
        onOpenAccount: (account) async {
          await context.push('/ip-accounts/${Uri.encodeComponent(account.id)}');
          if (mounted) await _load();
        },
      ),
    );
  }
}
