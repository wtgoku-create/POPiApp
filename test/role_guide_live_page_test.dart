import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/role_guide/presentation/role_guide_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';

import 'support/home_creation_fixtures.dart';

Future<ProviderContainer> pumpLive(
  WidgetTester tester,
  HomeCreationFixture fixture, {
  Size size = const Size(390, 844),
  String route = '/role-guide',
  Locale locale = const Locale('zh'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(fixture.business),
      agentDioProvider.overrideWithValue(fixture.agent),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(userProvider.notifier)
      .setUser(const User(id: 'user', name: 'Test', email: ''));
  container
      .read(safeAreaInsetsProvider.notifier)
      .update(const EdgeInsets.only(top: 30, bottom: 20));
  final router = container.read(routerProvider(false));
  addTearDown(router.dispose);
  router.go(route);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapLive(
  WidgetTester tester,
  String key, {
  bool running = false,
}) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  if (running) {
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  if (running) {
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'live flow uses server stories, pricing and tasks; pause stops polling',
    (tester) async {
      final fixture = HomeCreationFixture();
      final container = await pumpLive(tester, fixture);
      await tapLive(tester, 'role-guide-select-1');
      await tapLive(tester, 'role-guide-create-project');
      expect(find.text('Server story 1'), findsOneWidget);
      expect(
        container
            .read(routerProvider(false))
            .routeInformationProvider
            .value
            .uri
            .queryParameters['accountId'],
        '101',
      );
      await tapLive(tester, 'role-guide-choose-story');
      expect(fixture.selected!['id'], 'topic-1');
      await tapLive(tester, 'role-guide-configure');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Server video model'), findsOneWidget);
      expect(find.textContaining('42'), findsOneWidget);
      await tapLive(tester, 'home-config-confirm');
      await tapLive(tester, 'role-guide-produce', running: true);
      expect(fixture.task!['state'], 'queued');
      expect(find.textContaining('交互预览'), findsNothing);
      await tapLive(tester, 'role-guide-pause', running: true);
      expect(fixture.task!['state'], 'paused');
      final polls = fixture.requests
          .where(
            (request) =>
                request.method == 'GET' &&
                request.path.contains('/home-tasks/'),
          )
          .length;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(
        fixture.requests
            .where(
              (request) =>
                  request.method == 'GET' &&
                  request.path.contains('/home-tasks/'),
            )
            .length,
        polls,
      );
      await tapLive(tester, 'role-guide-generation-action', running: true);
      expect(fixture.task!['state'], 'running');
      fixture.task = fixture.taskValue(
        'completed',
        version: 8,
        lock: 'released',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('生成成功！'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'switch project reads ten-item account pages and restores home without creating a session',
    (tester) async {
      final fixture = HomeCreationFixture();
      final container = await pumpLive(tester, fixture);
      await tapLive(tester, 'role-guide-switch-project');
      await tapLive(tester, 'role-project-select-202');
      await tapLive(tester, 'role-project-confirm');
      expect(find.byType(RoleGuidePage), findsOneWidget);
      expect(fixture.accountId, '202');
      final accounts = fixture.requests
          .where((request) => request.path.endsWith('/accounts'))
          .toList();
      expect(accounts.map((request) => request.queryParameters), [
        {'page': 1, 'pageSize': 10},
        {'page': 2, 'pageSize': 10},
      ]);
      final entry = fixture.requests.firstWhere(
        (request) => request.path.endsWith('/home/enter'),
      );
      expect(entry.data['accountId'], '202');
      expect(entry.data.containsKey('sessionId'), isFalse);
      expect(
        fixture.requests.any(
          (request) => request.path.endsWith('/sessions/resolve'),
        ),
        isFalse,
      );
      expect(
        container
            .read(routerProvider(false))
            .routeInformationProvider
            .value
            .uri
            .queryParameters['accountId'],
        '202',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('entry retry keeps request ID; logout discards a late response', (
    tester,
  ) async {
    final fixture = HomeCreationFixture()..failEntryOnce = true;
    final container = await pumpLive(tester, fixture);
    await tapLive(tester, 'role-guide-select-1');
    await tapLive(tester, 'role-guide-create-project');
    expect(find.byKey(const Key('role-guide-request-retry')), findsOneWidget);
    fixture.waitForEntry = Completer<void>();
    await tester.tap(find.byKey(const Key('role-guide-request-retry')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final entries = fixture.requests
        .where((request) => request.path.endsWith('/home/enter'))
        .toList();
    expect(entries.length, 2);
    expect(entries.first.data, entries.last.data);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'other', name: 'Other', email: ''));
    fixture.waitForEntry!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Server story 1'), findsNothing);
    expect(find.byKey(const Key('role-guide-create-project')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets('saved live story fits English layout at $size', (
      tester,
    ) async {
      final fixture = HomeCreationFixture()
        ..selected = {
          'id': 'saved',
          'title': 'Saved story',
          'summary': 'A saved story',
        };
      await pumpLive(
        tester,
        fixture,
        size: size,
        locale: const Locale('en'),
        route: '/role-guide?accountId=101&sessionId=saved-session',
      );
      expect(find.text('Saved story'), findsOneWidget);
      await tapLive(tester, 'role-guide-configure');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Server video model'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
