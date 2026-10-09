import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_repository.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/payment_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

class _Tokens implements TokenStorage {
  @override
  Future<void> deleteAccessToken() async {}
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> writeAccessToken(String token) async {}
}

class _Repository extends AuthRepository {
  _Repository()
    : super(api: DefaultAuthApi(NetworkApi(Dio())), secureStorage: _Tokens());

  final refreshed = Completer<User>();

  @override
  Future<User> fetchCurrentUser() => refreshed.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'payment refresh cannot restore the previous account after switching',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _Repository();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          dioProvider.overrideWithValue(Dio()),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      const first = User(id: '1', name: 'First', email: '');
      const second = User(id: '2', name: 'Second', email: '');
      await container.read(userProvider.notifier).setUser(first);
      final service = container.read(androidPaymentServiceProvider);
      expect(service.available, isTrue);
      expect(service.storage.readAll(), isEmpty);
      final refreshing = service.onCompleted!();
      await container.read(userProvider.notifier).setUser(second);
      await container.pump();
      repository.refreshed.complete(first);
      await refreshing;
      expect(container.read(userProvider), second);
      expect(service.available, isFalse);
      expect(container.read(androidPaymentServiceProvider).storage.userId, '2');
      expect(container.read(userPointsProvider).valueOrNull, isNull);
    },
  );
}
