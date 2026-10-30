import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';

import '../../core/network/network_api.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/douyin_auth_api.dart';
import '../../features/auth/domain/douyin_app_login.dart';
import '../../features/auth/domain/user.dart';
import '../../features/auth/domain/user_points.dart';
import '../../features/auth/domain/wechat_app_login.dart';
import 'network_provider.dart';
import 'storage_provider.dart';
import '../type/user_type.dart';

final userProvider = NotifierProvider<UserController, User?>(
  UserController.new,
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final networkApi = NetworkApi(ref.watch(dioProvider));
  return AuthRepository(
    api: DefaultAuthApi(networkApi),
    secureStorage: ref.watch(secureStorageProvider),
    douyinApi: DefaultDouyinAuthApi(networkApi),
  );
});

final userStatusProvider = Provider<UserStatus>((ref) {
  return ref.watch(userProvider) == null
      ? UserStatus.guest
      : UserStatus.authenticated;
});

final userPointsProvider =
    AsyncNotifierProvider<UserPointsController, UserPoints?>(
      UserPointsController.new,
    );

final userBootstrapProvider = FutureProvider<void>((ref) async {
  final token = await ref.read(secureStorageProvider).readAccessToken();
  if (!(kIsWeb && AppConfig.businessAgentEnabled) &&
      (token == null || token.isEmpty)) {
    return;
  }

  try {
    await ref.read(userProvider.notifier).refreshUser();
  } on ApiException catch (error) {
    if ([401, 403].contains(error.statusCode)) return;
    rethrow;
  }
  await ref.read(userPointsProvider.notifier).refresh();
});

class UserController extends Notifier<User?> {
  int _sessionRevision = 0;

  @override
  User? build() => null;

  Future<void> setUser(User user) async {
    if (state?.id != user.id) _sessionRevision++;
    state = user;
  }

  Future<void> signInWithCode({
    required String phone,
    required String code,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .loginWithCode(phone: phone, code: code);
    await setUser(user);
    unawaited(ref.read(userPointsProvider.notifier).refresh());
  }

  Future<void> signInWithPassword({
    required String phone,
    required String password,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .loginWithPassword(phone: phone, password: password);
    await setUser(user);
    unawaited(ref.read(userPointsProvider.notifier).refresh());
  }

  Future<WechatAppSignInResult> signInWithWechatApp({
    required String code,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .loginWithWechatApp(code: code);
    if (result case WechatAppSignInSucceeded(user: final user)) {
      await setUser(user);
      unawaited(ref.read(userPointsProvider.notifier).refresh());
    }
    return result;
  }

  Future<void> registerWechatAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .registerWechatAppByPhone(
          registerToken: registerToken,
          phone: phone,
          code: code,
        );
    await setUser(user);
    unawaited(ref.read(userPointsProvider.notifier).refresh());
  }

  Future<DouyinAppSignInResult> signInWithDouyinApp({
    required String code,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .loginWithDouyinApp(code: code);
    if (result case DouyinAppSignInSucceeded(user: final user)) {
      await setUser(user);
      unawaited(ref.read(userPointsProvider.notifier).refresh());
    }
    return result;
  }

  Future<void> registerDouyinAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .registerDouyinAppByPhone(
          registerToken: registerToken,
          phone: phone,
          code: code,
        );
    await setUser(user);
    unawaited(ref.read(userPointsProvider.notifier).refresh());
  }

  Future<void> refreshUser() async {
    final revision = _sessionRevision;
    final user = await ref.read(authRepositoryProvider).fetchCurrentUser();
    if (revision == _sessionRevision) await setUser(user);
  }

  Future<void> updateUser({
    String? name,
    String? avatarUrl,
    String? signature,
  }) async {
    final currentUser = state;
    if (currentUser == null) return;
    final revision = _sessionRevision;
    final updatedUser = await ref
        .read(authRepositoryProvider)
        .updateUser(
          avatar: avatarUrl ?? currentUser.avatarUrl ?? '',
          name: name ?? currentUser.name,
          signature: signature ?? currentUser.signature,
        );
    if (revision == _sessionRevision) await setUser(updatedUser);
  }

  Future<void> clearUser() async {
    if (kIsWeb && AppConfig.businessAgentEnabled) {
      // HttpOnly Cookie 只能由服务端清除；退出失败时保留当前界面，避免刷新后意外恢复登录。
      await ref.read(authRepositoryProvider).logout();
    }
    _sessionRevision++;
    state = null;
    ref.read(userPointsProvider.notifier).clear();
    if (!(kIsWeb && AppConfig.businessAgentEnabled)) {
      await ref.read(authRepositoryProvider).logout();
    }
  }

  /// Agent 鉴权失效时只清理当前本地身份，避免用失效凭据发起额外退出请求。
  Future<void> expireSession(String expectedUserId) async {
    if (state?.id != expectedUserId) return;
    _sessionRevision++;
    state = null;
    ref.read(userPointsProvider.notifier).clear();
    await ref.read(secureStorageProvider).deleteAccessToken();
  }

  Future<void> cancelAccount() async {
    await ref.read(authRepositoryProvider).cancelAccount();
    _sessionRevision++;
    state = null;
    ref.read(userPointsProvider.notifier).clear();
  }
}

class UserPointsController extends AsyncNotifier<UserPoints?> {
  int _revision = 0;

  @override
  FutureOr<UserPoints?> build() => null;

  Future<void> refresh() async {
    final revision = ++_revision;
    state = const AsyncLoading();
    try {
      final points = await ref.read(authRepositoryProvider).fetchUserPoints();
      if (revision == _revision) state = AsyncData(points);
    } catch (error, stackTrace) {
      if (revision == _revision) state = AsyncError(error, stackTrace);
    }
  }

  void clear() {
    _revision++;
    state = const AsyncData(null);
  }
}
