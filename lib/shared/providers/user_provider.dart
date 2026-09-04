import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_api.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/user.dart';
import '../../features/auth/domain/user_points.dart';
import 'network_provider.dart';
import 'storage_provider.dart';
import '../type/user_type.dart';

final userProvider =
    NotifierProvider<UserController, User?>(UserController.new);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: DefaultAuthApi(NetworkApi(ref.watch(dioProvider))),
    secureStorage: ref.watch(secureStorageProvider),
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
  if (token == null || token.isEmpty) return;

  await ref.read(userProvider.notifier).refreshUser();
  await ref.read(userPointsProvider.notifier).refresh();
});

class UserController extends Notifier<User?> {
  @override
  User? build() => null;

  Future<void> setUser(User user) async {
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

  Future<void> refreshUser() async {
    await setUser(await ref.read(authRepositoryProvider).fetchCurrentUser());
  }

  Future<void> updateUser({
    String? name,
    String? avatarUrl,
    String? signature,
  }) async {
    final currentUser = state;
    if (currentUser == null) return;
    final updatedUser = await ref.read(authRepositoryProvider).updateUser(
          avatar: avatarUrl ?? currentUser.avatarUrl ?? '',
          name: name ?? currentUser.name,
          signature: signature ?? currentUser.signature,
        );
    await setUser(updatedUser);
  }

  Future<void> clearUser() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = null;
      ref.read(userPointsProvider.notifier).clear();
    }
  }
}

class UserPointsController extends AsyncNotifier<UserPoints?> {
  @override
  FutureOr<UserPoints?> build() => null;

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(
        await ref.read(authRepositoryProvider).fetchUserPoints(),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}
