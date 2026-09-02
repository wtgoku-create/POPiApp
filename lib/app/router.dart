import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/presentation/assets_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/points_details_page.dart';
import '../features/profile/presentation/profile_page.dart';

final routerProvider = Provider.family<GoRouter, bool>((ref, hasAccessToken) {
  return GoRouter(
    initialLocation: hasAccessToken ? '/' : '/login',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/assets',
        builder: (context, state) => const AssetsPage.sample(),
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
    ],
  );
});
