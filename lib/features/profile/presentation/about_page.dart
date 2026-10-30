import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../h5/presentation/h5_page.dart';
import 'widgets/profile_settings_row.dart';

/// Public agreements accessible from the profile's About entry.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.aboutPopiAi),
        leading: IconButton(
          tooltip: l10n.back,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 21),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            SettingsRow(
              key: const Key('profile-about-user-agreement'),
              icon: Icons.description_outlined,
              label: l10n.userAgreement,
              onTap: () => H5Page.open(
                context,
                title: l10n.userAgreement,
                url: Uri.parse(AppConfig.userAgreementUrl),
                location: '/legal/user-agreement',
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SettingsRow(
              key: const Key('profile-about-privacy-policy'),
              icon: Icons.privacy_tip_outlined,
              label: l10n.privacyPolicy,
              onTap: () => H5Page.open(
                context,
                title: l10n.privacyPolicy,
                url: Uri.parse(AppConfig.privacyPolicyUrl),
                location: '/legal/privacy-policy',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
