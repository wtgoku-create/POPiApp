import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../settings/presentation/settings_page.dart';
import 'widgets/profile_chrome.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ProfileTopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              children: [
                const Center(child: ProfileAvatar()),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    '啵啵',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'UID:09821',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.copy_outlined,
                      size: 17,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => context.push('/profile/edit'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: const Text(
                        '编辑资料',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const MembershipCard(),
                const SizedBox(height: 20),
                const SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.confirmation_number_outlined,
                      label: '账号管理',
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
