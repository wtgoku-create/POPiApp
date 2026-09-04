import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/app.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/auth_session.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/domain/user_points.dart';
import 'package:popi_ai_app/features/auth/presentation/login_page.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  testWidgets('holds a blank frame while restoring the session',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final tokenStorage = _DelayedTokenStorage();
    var readyCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(
              api: _StartupAuthApi(),
              secureStorage: tokenStorage,
            ),
          ),
        ],
        child: StarterApp(onReady: () => readyCalls += 1),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('app-startup-placeholder')), findsOneWidget);
    expect(readyCalls, 0);

    tokenStorage.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('app-startup-placeholder')), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(readyCalls, 1);
  });

  testWidgets('opens home when no access token is stored', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(
            const _MemoryTokenStorage(null),
          ),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(
              api: _StartupAuthApi(),
              secureStorage: const _MemoryTokenStorage(null),
            ),
          ),
        ],
        child: const StarterApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    final loginEntryLabel = tester.widget<Text>(
      find.byKey(const Key('home-membership-label')),
    );
    expect(loginEntryLabel.data, anyOf('前往登录', 'Sign in'));
    expect(find.byKey(const Key('home-membership-points')), findsNothing);
    expect(find.byKey(const Key('home-login-entry-icon')), findsOneWidget);
    expect(find.byKey(const Key('home-login-entry-chevron')), findsOneWidget);
    expect(loginEntryLabel.style?.color, AppColors.brand);

    const protectedDrawerEntries = [
      'drawer-nav-conversation',
      'drawer-nav-role',
      'drawer-nav-assets',
      'drawer-nav-inspiration',
      'drawer-nav-skill',
      'drawer-notification-button',
      'drawer-profile-button',
    ];
    for (final entryKey in protectedDrawerEntries) {
      await tester.tap(find.byKey(const Key('popi-open-navigation')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(entryKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginPage), findsOneWidget, reason: entryKey);
      Navigator.of(tester.element(find.byType(LoginPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HomePage), findsOneWidget, reason: entryKey);
    }

    await tester.tap(find.byKey(const Key('home-membership-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('does not open login when user bootstrap returns 4001',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const tokenStorage = _MemoryTokenStorage('expired-token');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(
              api: _ExpiredSessionAuthApi(),
              secureStorage: tokenStorage,
            ),
          ),
        ],
        child: const StarterApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('drawer routes preserve a back stack', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(
            const _MemoryTokenStorage('access-token'),
          ),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(
              api: _AuthenticatedAuthApi(),
              secureStorage: const _MemoryTokenStorage('access-token'),
            ),
          ),
        ],
        child: const StarterApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skill'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
    final profileContext = tester.element(find.byType(ProfilePage));
    expect(Navigator.of(profileContext).canPop(), isTrue);

    Navigator.of(profileContext).pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });
}

class _DelayedTokenStorage implements TokenStorage {
  final _completer = Completer<String?>();

  void complete(String? token) => _completer.complete(token);

  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<String?> readAccessToken() => _completer.future;

  @override
  Future<void> writeAccessToken(String value) async {}
}

class _MemoryTokenStorage implements TokenStorage {
  const _MemoryTokenStorage(this.token);

  final String? token;

  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String value) async {}
}

class _StartupAuthApi implements AuthApi {
  @override
  Future<CaptchaChallenge> createCaptcha() async => const CaptchaChallenge(
        id: 'test-captcha',
        imageBase64:
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

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
  Future<void> logout() => throw UnimplementedError();

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

class _AuthenticatedAuthApi extends _StartupAuthApi {
  @override
  Future<User> currentUser() async => const User(
        id: '10561',
        name: '阿🤔',
        email: 'user@popi.art',
        phone: '17313164895',
        isMember: true,
        memberLevel: 3,
      );

  @override
  Future<UserPoints> userPoints() async => const UserPoints(
        availableMemberPoints: 0,
        availableOtherPoints: 739,
        availableTotalPoints: 739,
        consumePoints: 18164,
      );
}

class _ExpiredSessionAuthApi extends _StartupAuthApi {
  @override
  Future<User> currentUser() =>
      throw const ApiException(statusCode: 4001, message: '登录已过期');
}
