import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/core/config/app_config.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/demo/data/demo_fixtures.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/shared/providers/business_agent_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/workspace_repository_provider.dart';

void main() {
  Future<ProviderContainer> containerFor(
    FutureOr<BusinessAgentSession?> Function() session, {
    Map<String, Object> cache = const {},
  }) async {
    SharedPreferences.setMockInitialValues(cache);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        businessAgentSessionProvider.overrideWith((ref) => session()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  BusinessAgentSession sessionFor(String id) {
    final dio = Dio(BaseOptions(baseUrl: 'https://agent.example'));
    addTearDown(() => dio.close(force: true));
    return BusinessAgentSession(
      userId: id,
      token: 'test-token',
      dio: dio,
      libraryApi: NetworkApi(dio),
      cacheNamespace: id,
      invalidate: () async {},
    );
  }

  test('signed-out entry has no repository or fixture conversations', () async {
    final container = await containerFor(() => null);
    final subscription = container.listen(
      workspaceRepositoryProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    expect(await container.read(workspaceRepositoryProvider.future), isNull);
  });

  test('restores owner cache and enables real business APIs', () async {
    final key = DemoRepository.businessStorageKey(
      AppConfig.environment,
      AppConfig.agentApiBaseUrl,
      'owner',
    );
    final container = await containerFor(
      () => sessionFor('owner'),
      cache: {
        key: jsonEncode({
          'sessions': DemoFixtures.sessions().map((s) => s.toJson()).toList(),
          'assets': [],
        }),
      },
    );
    final subscription = container.listen(
      workspaceRepositoryProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final repository = (await container.read(
      workspaceRepositoryProvider.future,
    ))!;
    expect(repository.isHarness, isTrue);
    expect(repository.usesBusinessLibrary, isTrue);
    expect(repository.supportsDirectUpload, isTrue);
    expect(repository.sessions, isNotEmpty);
  });

  test(
    'account change replaces repository and logout clears active state',
    () async {
      BusinessAgentSession? session = sessionFor('first');
      final container = await containerFor(() => session);
      final subscription = container.listen(
        workspaceRepositoryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final first = await container.read(workspaceRepositoryProvider.future);
      session = sessionFor('second');
      container.invalidate(businessAgentSessionProvider);
      final second = await container.read(workspaceRepositoryProvider.future);
      expect(second, isNot(same(first)));
      expect(second!.sessions, isEmpty);
      session = null;
      container.invalidate(businessAgentSessionProvider);
      expect(await container.read(workspaceRepositoryProvider.future), isNull);
    },
  );

  test(
    'session initialization failure propagates without fixture fallback',
    () async {
      final container = await containerFor(
        () => throw StateError('unavailable'),
      );
      final subscription = container.listen(
        workspaceRepositoryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await expectLater(
        container.read(workspaceRepositoryProvider.future),
        throwsStateError,
      );
      expect(container.read(workspaceRepositoryProvider).hasError, isTrue);
    },
  );

  test(
    'disposing during initialization does not create a repository',
    () async {
      final completer = Completer<BusinessAgentSession?>();
      final container = await containerFor(() => completer.future);
      final subscription = container.listen(
        workspaceRepositoryProvider,
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      await container.pump();
      completer.complete(sessionFor('late'));
      await container.pump();
      expect(container.exists(workspaceRepositoryProvider), isFalse);
    },
  );
}
