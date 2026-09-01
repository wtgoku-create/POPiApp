import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/auth_session.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/domain/user_points.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  testWidgets('confirming profile logout clears session and opens login page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _FakeAuthApi();
    final tokenStorage = _MemoryTokenStorage()..token = 'access-token';
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ProfilePage(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('登录页面')),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(api: api, secureStorage: tokenStorage),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logoutMenu = find.byKey(const Key('profile-logout-menu'));
    await tester.ensureVisible(logoutMenu);
    await tester.pumpAndSettle();
    await tester.tap(logoutMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-logout-button')));
    await tester.pumpAndSettle();

    expect(api.logoutCalls, 1);
    expect(tokenStorage.token, isNull);
    expect(find.text('登录页面'), findsOneWidget);
  });
}

class _FakeAuthApi implements AuthApi {
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<CaptchaChallenge> createCaptcha() => throw UnimplementedError();

  @override
  Future<User> currentUser() => throw UnimplementedError();

  @override
  Future<AuthSession> loginByCode({
    required String phone,
    required String code,
    String inviteCode = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendLoginCode({
    required String phone,
    required String captchaId,
    required String captchaValue,
  }) =>
      throw UnimplementedError();

  @override
  Future<User> updateUser({
    required String avatar,
    required String name,
    required String signature,
  }) =>
      throw UnimplementedError();

  @override
  Future<UserPoints> userPoints() => throw UnimplementedError();
}

class _MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> deleteAccessToken() async => token = null;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String token) async => this.token = token;
}
