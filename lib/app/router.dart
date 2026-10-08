import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/presentation/assets_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/ip_guide/presentation/ip_guide_page.dart';
import '../features/role_guide/presentation/role_guide_page.dart';
import '../features/ip_accounts/presentation/ip_accounts_page.dart';
import '../features/session/presentation/session_page.dart';
import '../core/config/app_config.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/pages/h5_page.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/membership_page.dart';
import '../features/profile/presentation/points_details_page.dart';
import '../features/profile/presentation/profile_page.dart';

final routerProvider = Provider.family<GoRouter, bool>((ref, _) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/ip-accounts',
        builder: (context, state) => const IpAccountsPage.sample(),
      ),
      GoRoute(
        path: '/ip-guide',
        builder: (context, state) => const IpGuidePage(),
      ),
      GoRoute(
        path: '/role-guide',
        builder: (context, state) => const RoleGuidePage(),
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) =>
            SessionPage(initialPrompt: state.uri.queryParameters['prompt']),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/legal/user-agreement',
        builder: (context, state) => H5Page(
          title: AppLocalizations.of(context)!.userAgreement,
          url: Uri.parse(AppConfig.userAgreementUrl),
        ),
      ),
      GoRoute(
        path: '/legal/privacy-policy',
        builder: (context, state) => H5Page(
          title: AppLocalizations.of(context)!.privacyPolicy,
          url: Uri.parse(AppConfig.privacyPolicyUrl),
        ),
      ),
      GoRoute(
        path: '/WeChat/:appId/oauth',
        builder: (context, state) => LoginPage(
          wechatAuthorizationCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        path: '/assets',
        builder: (context, state) => AssetsPage.sample(
          initialSection: state.uri.queryParameters['section'] == 'roles'
              ? AssetLibrarySection.roles
              : AssetLibrarySection.works,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/profile/points',
        builder: (context, state) => const PointsDetailsPage(),
      ),
      GoRoute(
        path: '/profile/membership',
        builder: (context, state) => const MembershipPage(),
      ),
    ],
  );
});
