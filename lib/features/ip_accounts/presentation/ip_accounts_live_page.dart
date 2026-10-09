import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/ip_account_provider.dart';
import '../../../shared/providers/user_provider.dart';
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
          .list(cancelToken: token);
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
      _accounts = const [];
      unawaited(_load());
    });
    return RefreshIndicator(
      onRefresh: _load,
      child: IpAccountsPage(
        accounts: _accounts,
        isLoading: _loading,
        onRetry: _failed ? _load : null,
        onOpenAccount: (account) async {
          await context.push('/ip-accounts/${Uri.encodeComponent(account.id)}');
          if (mounted) await _load();
        },
      ),
    );
  }
}
