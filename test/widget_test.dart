import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/app.dart';
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
  testWidgets('opens login when no access token is stored', (tester) async {
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

    expect(find.byType(LoginPage), findsOneWidget);
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
