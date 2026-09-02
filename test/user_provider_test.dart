import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/auth_session.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/domain/user_points.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  const user = User(id: '1', name: '张三', email: 'test@example.com');

  ProviderContainer createContainer(_FakeAuthApi api) {
    return ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(api: api, secureStorage: _MemoryTokenStorage()),
        ),
      ],
    );
  }

  test('keeps the current user in memory only', () async {
    final container = createContainer(_FakeAuthApi());
    addTearDown(container.dispose);

    await container.read(userProvider.notifier).setUser(user);
    expect(container.read(userProvider), user);

    final newContainer = createContainer(_FakeAuthApi());
    addTearDown(newContainer.dispose);
    expect(newContainer.read(userProvider), isNull);
  });

  test('parses the user code returned by the user information endpoint', () {
    final user = User.fromJson({
      'id': 10561,
      'code': 'u10561',
      'name': '当前用户',
      'email': 'user@popi.art',
    });

    expect(user.id, '10561');
    expect(user.code, 'u10561');
  });

  test('parses point balances returned by the user information endpoint', () {
    final user = User.fromJson({
      'id': 10561,
      'memberCoins': 1100,
      'otherCoins': 100,
      'pointPackageCoins': 88,
      'allCoins': 1750,
    });

    expect(user.memberCoins, 1100);
    expect(user.otherCoins, 100);
    expect(user.pointPackageCoins, 88);
    expect(user.allCoins, 1750);
  });

  test('loads user points into global state', () async {
    final container = createContainer(_FakeAuthApi());
    addTearDown(container.dispose);

    await container.read(userPointsProvider.notifier).refresh();

    expect(
      container.read(userPointsProvider).valueOrNull?.availableTotalPoints,
      739,
    );
  });

  test('refreshes user coin balances into global state', () async {
    final api = _FakeAuthApi();
    final container = createContainer(api);
    addTearDown(container.dispose);

    await container.read(userProvider.notifier).refreshUser();

    final refreshed = container.read(userProvider);
    expect(api.currentUserCalls, 1);
    expect(refreshed?.memberCoins, 1100);
    expect(refreshed?.otherCoins, 100);
    expect(refreshed?.pointPackageCoins, 88);
    expect(refreshed?.allCoins, 1750);
  });

  test('clears the user and points on logout', () async {
    final api = _FakeAuthApi();
    final container = createContainer(api);
    addTearDown(container.dispose);

    await container.read(userProvider.notifier).setUser(user);
    await container.read(userPointsProvider.notifier).refresh();
    await container.read(userProvider.notifier).clearUser();

    expect(container.read(userProvider), isNull);
    expect(container.read(userPointsProvider).valueOrNull, isNull);
    expect(api.logoutCalled, isTrue);
  });
}

class _FakeAuthApi implements AuthApi {
  bool logoutCalled = false;
  int currentUserCalls = 0;

  @override
  Future<CaptchaChallenge> createCaptcha() => throw UnimplementedError();

  @override
  Future<User> currentUser() async {
    currentUserCalls++;
    return const User(
      id: '1',
      name: '张三',
      email: 'test@example.com',
      memberCoins: 1100,
      otherCoins: 100,
      pointPackageCoins: 88,
      allCoins: 1750,
    );
  }

  @override
  Future<AuthSession> loginByCode({
    required String phone,
    required String code,
    String inviteCode = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async => logoutCalled = true;

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
  Future<UserPoints> userPoints() async => const UserPoints(
        availableMemberPoints: 0,
        availableOtherPoints: 739,
        availableTotalPoints: 739,
        consumePoints: 18164,
      );
}

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<void> writeAccessToken(String value) async {}
}
