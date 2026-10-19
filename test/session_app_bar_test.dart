import 'dart:async';

import 'package:dio/dio.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/domain/conversation_session.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

import 'conversation_events_test.dart'
    show chatId, chatMessageJson, chatSnapshotJson;
import 'support/session_fixtures.dart';

void main() {
  Future<(ProviderContainer, GoRouter)> pumpSession(
    WidgetTester tester,
    _SessionRepository repository, {
    bool guest = false,
    bool welcome = false,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    if (!guest) {
      await container
          .read(userProvider.notifier)
          .setUser(
            const User(id: 'a', name: 'User', email: '', allCoins: 12345),
          );
    }
    final router = GoRouter(
      initialLocation: welcome ? '/session' : '/session?sessionId=$chatId',
      routes: [
        GoRoute(
          path: '/session',
          builder: (_, state) =>
              SessionPage(sessionId: state.uri.queryParameters['sessionId']),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, router);
  }

  final newButton = find.byKey(const Key('session-new-conversation'));
  final input = find.byKey(const Key('popi-message-input'));
  Future<void> enter(WidgetTester tester, String text) async {
    await tester.tap(input);
    await tester.pumpAndSettle();
    tester.testTextInput.enterText(text);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final welcome in [false, true]) {
      testWidgets(
        'session app bar shows only its new action, dark=$dark welcome=$welcome',
        (tester) async {
          await pumpSession(
            tester,
            _SessionRepository(),
            welcome: welcome,
            theme: dark ? AppTheme.dark : AppTheme.light,
          );
          expect(newButton, findsOneWidget);
          expect(find.byTooltip('当前对话产物'), findsOneWidget);
          expect(find.byKey(const Key('home-membership-entry')), findsNothing);
          expect(find.byKey(const Key('popi-open-activity')), findsNothing);
          expect(find.text('12345'), findsNothing);
          expect(tester.getSize(newButton), const Size(40, 40));
          expect(tester.getRect(newButton).right, 305);
          final icon = tester.widget<AppSvgIcon>(
            find.descendant(of: newButton, matching: find.byType(AppSvgIcon)),
          );
          expect(icon.assetName, 'session_new_conversation');
          expect(
            icon.color,
            (dark ? AppTheme.dark : AppTheme.light).colorScheme.onSurface,
          );
          if (!welcome) expect(find.text('已有会话内容'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('outputs preserve the current conversation and draft', (
    tester,
  ) async {
    final repository = _SessionRepository();
    final (_, router) = await pumpSession(tester, repository);
    await tester.tap(input);
    tester.testTextInput.enterText('当前草稿');
    await tester.pump();
    await tester.tap(newButton);
    await tester.pumpAndSettle();
    expect(repository.createCalls, 0);
    expect(router.state.uri.queryParameters, {'sessionId': chatId});
    expect(tester.widget<ExtendedTextField>(input).controller!.text, '当前草稿');
    expect(find.text('已有会话内容'), findsOneWidget);
    expect(find.text('当前对话产物'), findsOneWidget);
    expect(find.byKey(const Key('session-artifacts-sheet')), findsOneWidget);
    await tester.tapAt(const Offset(160, 30));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-artifacts-sheet')), findsNothing);
    expect(tester.widget<ExtendedTextField>(input).controller!.text, '当前草稿');
    expect(repository.snapshotIds, [chatId]);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed first-send creation keeps the draft and retries on send',
    (tester) async {
      final repository = _SessionRepository()..failNext = true;
      final (_, router) = await pumpSession(tester, repository, welcome: true);
      await enter(tester, '保留这段草稿');
      final send = find.byKey(const Key('popi-send-button'));
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.queryParameters['sessionId'],
        isNull,
      );
      expect(find.text('已有会话内容'), findsNothing);
      expect(
        tester.widget<ExtendedTextField>(input).controller!.text,
        '保留这段草稿',
      );
      expect(tester.widget<IconButton>(newButton).onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(repository.createCalls, 2);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['sessionId'],
        'mock-new-1',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guest can preview mock outputs without leaving the page', (
    tester,
  ) async {
    final repository = _SessionRepository();
    final (_, router) = await pumpSession(
      tester,
      repository,
      guest: true,
      welcome: true,
    );
    await tester.tap(newButton);
    await tester.pumpAndSettle();
    expect(find.text('Login page'), findsNothing);
    expect(find.text('当前对话产物'), findsOneWidget);
    expect(router.state.uri.path, '/session');
    expect(repository.createCalls, 0);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('account changes discard pending creation results', (
    tester,
  ) async {
    final repository = _SessionRepository()..pending = Completer<void>();
    final (container, router) = await pumpSession(
      tester,
      repository,
      welcome: true,
    );
    await enter(tester, 'Do not send after switching users');
    await tester.tap(find.byKey(const Key('popi-send-button')));
    await tester.pump();
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'b', name: 'B', email: ''));
    await tester.pump();
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.queryParameters['sessionId'],
      isNull,
    );
    expect(repository.snapshotIds, isEmpty);
    expect(
      (await container.read(
        sessionsProvider.future,
      )).any((item) => item.id == 'mock-new-1'),
      isFalse,
    );
    expect(tester.widget<IconButton>(newButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

class _SessionRepository extends FixtureSessionRepository {
  Completer<void>? pending;
  bool failNext = false;
  int createCalls = 0;
  final snapshotIds = <String>[];

  @override
  Future<ConversationSession> create(
    String userId,
    String title, {
    CancelToken? cancelToken,
  }) async {
    createCalls++;
    await pending?.future;
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    return super.create(userId, title, cancelToken: cancelToken);
  }

  @override
  Future<ConversationSnapshot> snapshot(String id, {CancelToken? cancelToken}) {
    snapshotIds.add(id);
    if (id == chatId) {
      return Future.value(
        ConversationSnapshot.fromJson(
          chatSnapshotJson(seq: 1, messages: [chatMessageJson(text: '已有会话内容')]),
        ),
      );
    }
    return super.snapshot(id, cancelToken: cancelToken);
  }
}
