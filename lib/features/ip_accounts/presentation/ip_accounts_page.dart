import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_account_icon.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../data/ip_account_examples.dart';
import '../domain/ip_account.dart';
import 'widgets/ip_accounts_skeleton.dart';

/// Account management layout with injectable data and loading state.
class IpAccountsPage extends ConsumerWidget {
  const IpAccountsPage({
    this.accounts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.onOpenAccount,
    this.onRetry,
    this.onDeleteAccount,
    this.isDeleting = false,
    this.deletingAccountId,
    super.key,
  });

  const IpAccountsPage.sample({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.onOpenAccount,
    this.onRetry,
    this.onDeleteAccount,
    this.isDeleting = false,
    this.deletingAccountId,
    super.key,
  }) : accounts = ipAccountExamples;

  final List<IpAccount> accounts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final ValueChanged<IpAccount>? onOpenAccount;
  final VoidCallback? onRetry;
  final ValueChanged<IpAccount>? onDeleteAccount;
  final bool isDeleting;
  final String? deletingAccountId;

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
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                l10n.noIpAccounts,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        )
                : LayoutBuilder(
                    builder: (context, constraints) => SlidableAutoCloseBehavior(
                      child: ListView.separated(
                        key: const Key('ip-accounts-list'),
                        padding: listPadding,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: accounts.length + (hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == accounts.length) {
                            return SizedBox(
                              height: 48,
                              child: isLoadingMore
                                  ? AppSkeleton(
                                      label: l10n.loadingProjects,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: AppSkeletonBox(height: 16),
                                      ),
                                    )
                                  : null,
                            );
                          }
                          final account = accounts[index];
                          return Slidable(
                            key: ValueKey('ip-account-slide-${account.id}'),
                            enabled:
                                onDeleteAccount != null &&
                                !isDeleting &&
                                !isLoading,
                            endActionPane: ActionPane(
                              extentRatio: math.min(
                                1,
                                100 / math.max(1, constraints.maxWidth - 40),
                              ),
                              motion: const ScrollMotion(),
                              children: [
                                const SizedBox(width: 10),
                                CustomSlidableAction(
                                  key: Key('ip-account-delete-${account.id}'),
                                  onPressed: (_) {
                                    if (!isDeleting && !isLoading) {
                                      onDeleteAccount?.call(account);
                                    }
                                  },
                                  backgroundColor: const Color(0xFFCC4646),
                                  foregroundColor: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Transform.rotate(
                                        angle: math.pi / 2,
                                        child: const AppSvgIcon.asset(
                                          'role_swipe_delete',
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        l10n.delete,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            child: _AccountCard(
                              key: ValueKey('ip-account-${account.id}'),
                              account: account,
                              deleting: deletingAccountId == account.id,
                              onTap: isDeleting
                                  ? null
                                  : () {
                                      if (onOpenAccount case final callback?) {
                                        callback(account);
                                      } else {
                                        context.push(
                                          '/ip-accounts/${Uri.encodeComponent(account.id)}',
                                        );
                                      }
                                    },
                            ),
                          );
                        },
                      ),
                    ),
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
    required this.onTap,
    required this.deleting,
    super.key,
  });

  final IpAccount account;
  final VoidCallback? onTap;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
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
              AppAccountIcon(
                key: ValueKey('ip-account-icon-${account.id}'),
                backgroundColor: account.iconBackgroundColor,
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
                                ? l10n.accountArchived
                                : l10n.accountActive,
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
                    child: deleting
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : SizedBox(
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
