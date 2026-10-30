import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/data/demo_fixtures.dart';

void main() {
  test(
    'restores only the same business user and environment without importing test history',
    () async {
      final a = DemoRepository.businessStorageKey(
        'test',
        'https://agent.example',
        '101',
      );
      final b = DemoRepository.businessStorageKey(
        'test',
        'https://agent.example',
        '102',
      );
      final otherEnvironment = DemoRepository.businessStorageKey(
        'prod',
        'https://agent.example',
        '101',
      );
      final snapshot = jsonEncode({
        'sessions': DemoFixtures.sessions().map((s) => s.toJson()).toList(),
        'assets': [],
      });
      SharedPreferences.setMockInitialValues({
        a: snapshot,
        DemoRepository.harnessStorageKey: snapshot,
      });
      final storage = PreferencesStorage(await SharedPreferences.getInstance());
      final dio = Dio(BaseOptions(baseUrl: 'https://agent.example'));
      addTearDown(() => dio.close(force: true));
      final api = NetworkAgentApi(dio);
      for (final key in [a, b, otherEnvironment]) {
        final repository = DemoRepository.harness(
          storage,
          api,
          userStorageKey: key,
        )..restore();
        expect(repository.sessions.isNotEmpty, key == a);
        repository.dispose();
      }
      final restored = DemoRepository.harness(storage, api, userStorageKey: a)
        ..restore();
      expect(restored.sessions, isNotEmpty);
      restored.dispose();
      expect(storage.getString(b), isNull);
    },
  );
}
