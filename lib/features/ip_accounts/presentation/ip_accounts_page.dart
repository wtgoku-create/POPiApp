import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../data/ip_account_examples.dart';
import '../domain/ip_account.dart';
import 'widgets/ip_accounts_skeleton.dart';

/// Account management layout with injectable data and loading state.
class IpAccountsPage extends ConsumerWidget {
  const IpAccountsPage({
    this.accounts = const [],
    this.isLoading = false,
    this.onOpenAccount,
    this.onRetry,
    super.key,
  });

  const IpAccountsPage.sample({
    this.isLoading = false,
    this.onOpenAccount,
    this.onRetry,
    super.key,
  }) : accounts = ipAccountExamples;

  final List<IpAccount> accounts;
  final bool isLoading;
  final ValueChanged<IpAccount>? onOpenAccount;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final top = math.max(
      52.0,
      math.max(safeArea.top, MediaQuery.viewPaddingOf(context).top),
    );
    final listPadding = EdgeInsets.fromLTRB(
      20,
      0,
      20,
      math.max(20, safeArea.bottom),
    );

    return Scaffold(
      drawer: const PopiNavigationDrawer(),
      backgroundColor: colors.brightness == Brightness.light
          ? const Color(0xFFF5F4FA)
          : colors.surface,
      body: Column(
        children: [
          SizedBox(height: top),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 15),
                SizedBox.square(
                  dimension: 40,
                  child: Builder(
                    builder: (context) => IconButton(
                      key: const Key('popi-open-navigation'),
                      tooltip: l10n.openNavigation,
                      padding: const EdgeInsets.all(5),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: AppSvgIcon.asset(
                        'common_navigation_menu',
                        size: 30,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.ipAccountsTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: accounts.isEmpty
                ? isLoading
                      ? IpAccountsSkeleton(
                          key: const Key('ip-accounts-skeleton'),
                          padding: listPadding,
                        )
                      : onRetry != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.ipAccountLoadFailed),
                              TextButton(
                                onPressed: onRetry,
                                child: Text(l10n.retry),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Text(
                            l10n.noIpAccounts,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        )
                : ListView.separated(
                    key: const Key('ip-accounts-list'),
                    padding: listPadding,
                    itemCount: accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return _AccountCard(
                        key: ValueKey('ip-account-${account.id}'),
                        account: account,
                        colorIndex: index,
                        onTap: () {
                          if (onOpenAccount case final callback?) {
                            callback(account);
                          } else {
                            context.push(
                              '/ip-accounts/${Uri.encodeComponent(account.id)}',
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.colorIndex,
    required this.onTap,
    super.key,
  });

  final IpAccount account;
  final int colorIndex;
  final VoidCallback onTap;

  static const _avatarColors = [
    AppColors.brand,
    Color(0xFFFA51A2),
    Color(0xFFFF9A27),
    Color(0xFF3E975B),
    Color(0xFF33A0F8),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final avatarColor = _avatarColors[colorIndex % _avatarColors.length];
    final statusColor = account.isPaused
        ? colors.brightness == Brightness.light
              ? AppColors.textTertiary
              : colors.onSurfaceVariant
        : colors.brightness == Brightness.light
        ? const Color(0xFF0F9E3F)
        : const Color(0xFFA0EB91);

    return Material(
      color: colors.brightness == Brightness.light
          ? colors.surface
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  account.title.characters.firstOrNull ?? '',
                  style: TextStyle(
                    color: avatarColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: account.isPaused
                                ? statusColor.withValues(alpha: .12)
                                : const Color(
                                    0xFFA0EB91,
                                  ).withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            account.isPaused
                                ? l10n.ipAccountPausedStatus
                                : l10n.ipAccountNormalStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      account.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Transform.translate(
                offset: const Offset(0, -12.5),
                child: SizedBox.square(
                  dimension: 20,
                  child: Center(
                    child: SizedBox(
                      width: 8,
                      height: 12,
                      child: AppSvgIcon.asset(
                        'ip_account_chevron',
                        color: colors.brightness == Brightness.light
                            ? AppColors.textTertiary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
