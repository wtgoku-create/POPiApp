import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/auth_session.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/domain/user_points.dart';

void main() {
  test('initializes the current user after saving the login token', () async {
    final events = <String>[];
    final storage = _EventTokenStorage(events);
    final api = _FakeAuthApi(events);
    final repository = AuthRepository(api: api, secureStorage: storage);

    final user = await repository.loginWithCode(
      phone: '13800138000',
      code: '123456',
    );

    expect(user.name, '初始化用户');
    expect(storage.token, 'token-from-login');
    expect(events, ['login', 'save-token', 'current-user']);
  });

  test('clears the token when login state initialization fails', () async {
    final storage = _EventTokenStorage([]);
    final repository = AuthRepository(
      api: _FakeAuthApi([], failCurrentUser: true),
      secureStorage: storage,
    );

    await expectLater(
      repository.loginWithCode(phone: '13800138000', code: '123456'),
      throwsStateError,
    );
    expect(storage.token, isNull);
  });
}

class _FakeAuthApi implements AuthApi {
  _FakeAuthApi(this.events, {this.failCurrentUser = false});

  final List<String> events;
  final bool failCurrentUser;

  @override
  Future<CaptchaChallenge> createCaptcha() {
    throw UnimplementedError();
  }

  @override
  Future<User> currentUser() async {
    events.add('current-user');
    if (failCurrentUser) throw StateError('user initialization failed');
    return const User(id: '2', name: '初始化用户', email: 'user@popi.art');
  }

  @override
  Future<AuthSession> loginByCode({
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    events.add('login');
    return const AuthSession(
      accessToken: 'token-from-login',
      user: User(id: '2', name: '登录响应用户', email: ''),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendLoginCode({
    required String phone,
    required String captchaId,
    required String captchaValue,
  }) {
    throw UnimplementedError();
  }

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

class _EventTokenStorage implements TokenStorage {
  _EventTokenStorage(this.events);

  final List<String> events;
  String? token;

  @override
  Future<void> deleteAccessToken() async => token = null;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String value) async {
    events.add('save-token');
    token = value;
  }
}
