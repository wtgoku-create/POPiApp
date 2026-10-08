import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../data/ip_account_examples.dart';
import '../domain/ip_account.dart';

enum _AccountFilter { all, recent, paused }

/// Account management layout with page-local filtering and injectable data.
class IpAccountsPage extends ConsumerStatefulWidget {
  const IpAccountsPage({
    this.accounts = const [],
    this.onOpenAccount,
    super.key,
  });

  const IpAccountsPage.sample({this.onOpenAccount, super.key})
    : accounts = ipAccountExamples;

  final List<IpAccount> accounts;
  final ValueChanged<IpAccount>? onOpenAccount;

  @override
  ConsumerState<IpAccountsPage> createState() => _IpAccountsPageState();
}

class _IpAccountsPageState extends ConsumerState<IpAccountsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  _AccountFilter _filter = _AccountFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final top = math.max(
      52.0,
      math.max(safeArea.top, MediaQuery.viewPaddingOf(context).top),
    );
    final accounts = widget.accounts
        .where(
          (account) => switch (_filter) {
            _AccountFilter.all => true,
            _AccountFilter.recent => account.isRecentlyUsed,
            _AccountFilter.paused => account.isPaused,
          },
        )
        .toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.brightness == Brightness.light
          ? const Color(0xFFF5F4FA)
          : colors.surface,
      drawer: const PopiNavigationDrawer(),
      drawerScrimColor: const Color(0x33333333),
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
                  child: IconButton(
                    key: const Key('ip-accounts-open-navigation'),
                    tooltip: l10n.openNavigation,
                    padding: const EdgeInsets.all(5),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: AppSvgIcon.asset(
                      'common_navigation_menu',
                      size: 30,
                      color: colors.onSurface,
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
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _AccountFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final filter = _AccountFilter.values[index];
                final selected = filter == _filter;
                final label = switch (filter) {
                  _AccountFilter.all => l10n.ipAccountsAll,
                  _AccountFilter.recent => l10n.ipAccountsRecent,
                  _AccountFilter.paused => l10n.ipAccountsPaused,
                };
                return Semantics(
                  selected: selected,
                  child: TextButton(
                    key: Key('ip-accounts-filter-${filter.name}'),
                    onPressed: () => setState(() => _filter = filter),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(
                        filter == _AccountFilter.recent ? 105 : 76,
                        36,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      backgroundColor: selected
                          ? colors.primary.withValues(alpha: .05)
                          : Colors.transparent,
                      foregroundColor: selected
                          ? colors.onSurface
                          : colors.brightness == Brightness.light
                          ? AppColors.textTertiary
                          : colors.onSurfaceVariant,
                      shape: const StadiumBorder(),
                      textStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    child: Text(label),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: accounts.isEmpty
                ? Center(
                    child: Text(switch (_filter) {
                      _AccountFilter.all => l10n.noIpAccounts,
                      _AccountFilter.recent => l10n.noRecentIpAccounts,
                      _AccountFilter.paused => l10n.noPausedIpAccounts,
                    }, style: TextStyle(color: colors.onSurfaceVariant)),
                  )
                : ListView.separated(
                    key: const Key('ip-accounts-list'),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      math.max(20, safeArea.bottom),
                    ),
                    itemCount: accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return _AccountCard(
                        key: ValueKey('ip-account-${account.id}'),
                        account: account,
                        colorIndex: widget.accounts.indexOf(account),
                        onTap: () {
                          if (widget.onOpenAccount case final callback?) {
                            callback(account);
                          } else {
                            AppToast.info(
                              context,
                              l10n.ipAccountDetailsPending,
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
