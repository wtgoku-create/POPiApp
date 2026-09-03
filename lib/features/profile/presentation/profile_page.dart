import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/network/network_api.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/network_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/point_package_repository.dart';
import 'points_details_page.dart';
import 'widgets/profile_chrome.dart';

final _languageMenuExpandedProvider = StateProvider<bool>((ref) => false);
final _themeMenuExpandedProvider = StateProvider<bool>((ref) => false);

class ProfilePage extends ConsumerWidget {
  const ProfilePage({this.pointPackageLoader, super.key});

  final PointPackageLoader? pointPackageLoader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final displayName = user?.name.isNotEmpty == true ? user!.name : '--';
    final displayId =
        user?.code.isNotEmpty == true ? user!.code : user?.id ?? '--';
    final displayPhone =
        user?.phone.isNotEmpty == true ? _maskedPhone(user!.phone) : '--';
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final languageExpanded = ref.watch(_languageMenuExpandedProvider);
    final themeExpanded = ref.watch(_themeMenuExpandedProvider);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final VoidCallback? copyUid = displayId == '--'
        ? null
        : () async {
            await Clipboard.setData(ClipboardData(text: displayId));
            if (context.mounted) {
              AppToast.success(context, l10n.uidCopied);
            }
          };

    return Scaffold(
      body: Column(
        children: [
          const ProfileTopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              children: [
                Center(child: ProfileAvatar(imageUrl: user?.avatarUrl)),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Tooltip(
                    message: l10n.copyAction,
                    child: InkWell(
                      key: const Key('profile-uid-copy'),
                      onTap: copyUid,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          height: 40,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'UID:$displayId',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy_outlined,
                                size: 17,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => context.push('/profile/edit'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: Text(
                        l10n.editProfile,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                MembershipCard(pointPackageLoader: pointPackageLoader),
                const SizedBox(height: 20),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      iconWidget: const AppSvgIcon.asset(
                        'profile_settings_account',
                        size: 20,
                      ),
                      label: l10n.accountManagement,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      iconWidget: AppSvgIcon.asset(
                        'profile_settings_phone',
                        size: 20,
                      ),
                      label: l10n.phoneNumber,
                      value: '+86 $displayPhone',
                    ),
                    SettingsRow(
                      iconWidget: AppSvgIcon.asset(
                        'profile_settings_wechat',
                        size: 21,
                      ),
                      label: l10n.wechatId,
                      value: 'dssads222',
                    ),
                    SettingsRow(
                      iconWidget: AppSvgIcon.asset(
                        'profile_settings_douyin',
                        size: 20,
                      ),
                      label: l10n.douyin,
                      value: 'Alice',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SettingsGroup(
                  children: [
                    TreeSettingsMenu(
                      menuKey: const Key('language-settings-menu'),
                      icon: Icons.translate,
                      label: l10n.language,
                      value: _languageLabel(locale, l10n),
                      expanded: languageExpanded,
                      onToggle: () => ref
                          .read(_languageMenuExpandedProvider.notifier)
                          .state = !languageExpanded,
                      options: [
                        TreeSettingsOption(
                          label: l10n.chinese,
                          selected: locale?.languageCode == 'zh',
                          onTap: () async {
                            await ref
                                .read(localeProvider.notifier)
                                .setLocale(const Locale('zh'));
                            ref
                                .read(_languageMenuExpandedProvider.notifier)
                                .state = false;
                          },
                        ),
                        TreeSettingsOption(
                          label: l10n.english,
                          selected: locale?.languageCode == 'en',
                          onTap: () async {
                            await ref
                                .read(localeProvider.notifier)
                                .setLocale(const Locale('en'));
                            ref
                                .read(_languageMenuExpandedProvider.notifier)
                                .state = false;
                          },
                        ),
                        TreeSettingsOption(
                          label: l10n.system,
                          selected: locale == null,
                          onTap: () async {
                            await ref
                                .read(localeProvider.notifier)
                                .setLocale(null);
                            ref
                                .read(_languageMenuExpandedProvider.notifier)
                                .state = false;
                          },
                        ),
                      ],
                    ),
                    TreeSettingsMenu(
                      menuKey: const Key('theme-settings-menu'),
                      icon: Icons.dark_mode_outlined,
                      label: l10n.theme,
                      value: _themeLabel(themeMode, l10n),
                      expanded: themeExpanded,
                      onToggle: () => ref
                          .read(_themeMenuExpandedProvider.notifier)
                          .state = !themeExpanded,
                      options: [
                        TreeSettingsOption(
                          label: l10n.light,
                          selected: themeMode == ThemeMode.light,
                          onTap: () async {
                            await ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.light);
                            ref
                                .read(_themeMenuExpandedProvider.notifier)
                                .state = false;
                          },
                        ),
                        TreeSettingsOption(
                          label: l10n.dark,
                          selected: themeMode == ThemeMode.dark,
                          onTap: () async {
                            await ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.dark);
                            ref
                                .read(_themeMenuExpandedProvider.notifier)
                                .state = false;
                          },
                        ),
                        TreeSettingsOption(
                          label: l10n.system,
                          selected: themeMode == ThemeMode.system,
                          onTap: () async {
                            await ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.system);
                            ref
                                .read(_themeMenuExpandedProvider.notifier)
                                .state = false;
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsRow(
                      key: const Key('profile-logout-menu'),
                      icon: Icons.logout,
                      label: l10n.logout,
                      showChevron: false,
                      onTap: () => _confirmLogout(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppSheet.show<bool>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.logout,
              style: TextStyle(
                color: Theme.of(sheetContext).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.logoutDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const Key('confirm-logout-button'),
                onPressed: () => Navigator.of(sheetContext).pop(true),
                icon: const Icon(Icons.logout),
                label: Text(l10n.confirmLogout),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD92D20),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(sheetContext)
                      .colorScheme
                      .surfaceContainerHighest,
                  foregroundColor: Theme.of(sheetContext).colorScheme.onSurface,
                  shape: const StadiumBorder(),
                ),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(userProvider.notifier).clearUser();
      if (context.mounted) context.go('/login');
    } catch (_) {
      if (context.mounted) AppToast.error(context, l10n.logoutFailed);
    }
  }

  String _maskedPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}*******${phone.substring(phone.length - 2)}';
  }

  String _languageLabel(Locale? locale, AppLocalizations l10n) =>
      switch (locale?.languageCode) {
        'zh' => l10n.chinese,
        'en' => l10n.english,
        _ => l10n.system,
      };

  String _themeLabel(ThemeMode mode, AppLocalizations l10n) => switch (mode) {
        ThemeMode.light => l10n.light,
        ThemeMode.dark => l10n.dark,
        ThemeMode.system => l10n.system,
      };
}

class MembershipCard extends ConsumerWidget {
  const MembershipCard({this.pointPackageLoader, super.key});

  final PointPackageLoader? pointPackageLoader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);
    final points = ref.watch(userPointsProvider).valueOrNull;
    final colorScheme = Theme.of(context).colorScheme;
    final memberLabel = user?.isMember == true
        ? l10n.memberLevel(user!.memberLevel.toString())
        : l10n.regularUser;
    final totalPoints = user?.allCoins ?? points?.availableTotalPoints;

    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                memberLabel,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 40,
                child: FilledButton(
                  key: const Key('profile-upgrade-membership'),
                  onPressed: () => context.push('/profile/membership'),
                  child: Text(
                    l10n.upgradeMembership,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 40,
            child: Material(
              key: const Key('profile-points-entry'),
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const AppSvgIcon.asset(
                      'common_brand_icon-vector',
                      key: Key('profile-points-icon'),
                      size: 12,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      totalPoints?.toString() ?? '--',
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      key: const Key('profile-points-recharge'),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      onTap: () async {
                        final loader = pointPackageLoader ??
                            PointPackageRepository(
                              NetworkApi(ref.read(dioProvider)),
                            ).fetchAll;
                        await showRechargePointsSheet(
                          context: context,
                          totalPoints: totalPoints ?? 0,
                          loadPackages: loader,
                          onPurchase: pointPackageLoader == null
                              ? (context, package) =>
                                  purchasePointPackage(context, ref, package)
                              : null,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 8,
                        ),
                        child: Text(
                          l10n.rechargeAction,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '|',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    InkWell(
                      key: const Key('profile-points-details'),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      onTap: () => context.push('/profile/points'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 8,
                        ),
                        child: Text(
                          l10n.pointsDetailsTitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              )
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(children: children),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    this.icon,
    this.iconWidget,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    super.key,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 22,
                child: Center(
                  child: iconWidget == null
                      ? Icon(
                          icon,
                          size: 22,
                          color: colorScheme.onSurface,
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                          child: iconWidget!,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (showChevron) ...[
                const SizedBox(width: 7),
                if (trailing == null)
                  AppSvgIcon.asset(
                    'profile_settings_chevron',
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  )
                else
                  Icon(
                    trailing,
                    size: 21,
                    color: colorScheme.onSurfaceVariant,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TreeSettingsMenu extends StatelessWidget {
  const TreeSettingsMenu({
    required this.menuKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.expanded,
    required this.onToggle,
    required this.options,
    super.key,
  });

  final Key menuKey;
  final IconData icon;
  final String label;
  final String value;
  final bool expanded;
  final VoidCallback onToggle;
  final List<TreeSettingsOption> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: menuKey,
      children: [
        SettingsRow(
          icon: icon,
          label: label,
          value: value,
          trailing: expanded ? Icons.expand_less : Icons.expand_more,
          onTap: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 20),
            child: Column(children: options),
          ),
      ],
    );
  }
}

class TreeSettingsOption extends StatelessWidget {
  const TreeSettingsOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check,
                  color: colorScheme.primary,
                  size: 20,
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
