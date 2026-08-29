import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../profile/presentation/widgets/profile_chrome.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const ProfileTopBar(showSettings: false),
          Expanded(
            child: ListView(
              key: const Key('settings-list'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 68),
              children: [
                const MembershipCard(),
                const SizedBox(height: 20),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.confirmation_number_outlined,
                      label: '账号管理',
                      onTap: () => context.push('/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.phone_android_outlined,
                      label: '手机号',
                      value: '+86 132*******92',
                    ),
                    SettingsRow(
                      icon: Icons.wechat,
                      label: '微信号',
                      value: 'dssads222',
                    ),
                    SettingsRow(
                      icon: Icons.music_note,
                      label: '抖音',
                      value: 'Alice',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SettingsGroup(
                  children: [
                    SettingsRow(icon: Icons.build_outlined, label: 'Skill'),
                    SettingsRow(
                      icon: Icons.request_quote_outlined,
                      label: '自主开票',
                    ),
                    SettingsRow(
                      icon: Icons.approval_outlined,
                      label: 'AI水印设置',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.translate,
                      label: '中文',
                      trailing: Icons.swap_horiz,
                      onTap: () {
                        final current = ref.read(localeProvider);
                        ref.read(localeProvider.notifier).setLocale(
                              Locale(
                                  current.languageCode == 'zh' ? 'en' : 'zh'),
                            );
                      },
                    ),
                    const SettingsRow(
                      icon: Icons.logout,
                      label: '退出登录',
                      showChevron: false,
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
}

class MembershipCard extends StatelessWidget {
  const MembershipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceTintStrong,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '普通用户',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('升级会员', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: const Row(
              children: [
                Icon(Icons.videocam, color: AppColors.brand, size: 18),
                SizedBox(width: 3),
                Text('1288', style: TextStyle(fontSize: 18)),
                Spacer(),
                Text('充值 | 积分详情', style: TextStyle(fontSize: 16)),
              ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              if (showChevron) ...[
                const SizedBox(width: 7),
                Icon(
                  trailing ?? Icons.chevron_right,
                  size: 21,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
