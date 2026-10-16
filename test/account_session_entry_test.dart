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
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/session_fixtures.dart';

class _AccountSessions extends FixtureSessionRepository {
  final resolutions = <String>[];
  final sent = <(String, String)>[];
  ConversationSession? binding;
  Completer<void>? pending;
  CancelToken? resolutionToken;
  bool failLookup = false;
  bool failSend = false;
  int creates = 0;

  @override
  Future<ConversationSession> create(
    String userId,
    String title, {
    CancelToken? cancelToken,
  }) {
    creates++;
    return super.create(userId, title, cancelToken: cancelToken);
  }

  @override
  Future<ConversationSession> resolveAccountSession(
    String userId,
    String accountId,
    String title, {
    CancelToken? cancelToken,
  }) async {
    resolutions.add(accountId);
    resolutionToken = cancelToken;
    await pending?.future;
    if (failLookup) throw StateError('offline');
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    return binding ??= await create(userId, title, cancelToken: cancelToken);
  }

  @override
  Future<void> send(
    String userId,
    String id,
    String text,
    List<String> mediaIds, {
    List<String> roleIds = const [],
    CancelToken? cancelToken,
  }) async {
    sent.add((id, text));
    if (failSend) throw StateError('offline');
  }
}

void main() {
  final input = find.byKey(const Key('popi-message-input'));
  final send = find.byKey(const Key('popi-send-button'));
  late _AccountSessions repository;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.tap(input);
    await tester.pumpAndSettle();
    tester.testTextInput.enterText(text);
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester) async {
    repository = _AccountSessions();
    container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'user', name: 'User', email: ''));
    router = GoRouter(
      initialLocation: '/session?accountId=42',
      routes: [
        GoRoute(
          path: '/session',
          builder: (_, state) => SessionPage(
            accountId: state.uri.queryParameters['accountId'],
            sessionId: state.uri.queryParameters['sessionId'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.resolutions, isEmpty);
    expect(repository.creates, 0);
  }

  for (final alreadyBound in [false, true]) {
    testWidgets('first send resolves account binding: bound=$alreadyBound', (
      tester,
    ) async {
      await pump(tester);
      if (alreadyBound) {
        repository.binding = ConversationSession(
          id: 'existing-session',
          title: 'Existing',
          updatedAt: DateTime(2026),
        );
      }
      await enter(tester, 'Create content for this account');
      await tester.tap(send);
      await tester.pumpAndSettle();
      final id = alreadyBound ? 'existing-session' : 'mock-new-1';
      expect(repository.resolutions, ['42']);
      expect(repository.creates, alreadyBound ? 0 : 1);
      expect(repository.sent, [(id, 'Create content for this account')]);
      expect(router.state.uri.queryParameters, {'sessionId': id});
      expect(tester.widget<ExtendedTextField>(input).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed lookup retains draft and rechecks binding on retry', (
    tester,
  ) async {
    await pump(tester);
    repository.failLookup = true;
    await enter(tester, 'Keep this draft');
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repository.creates, 0);
    expect(repository.sent, isEmpty);
    expect(router.state.uri.queryParameters, {'accountId': '42'});
    expect(
      tester.widget<ExtendedTextField>(input).controller!.text,
      'Keep this draft',
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    repository.failLookup = false;
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repository.resolutions, ['42', '42']);
    expect(repository.creates, 1);
    expect(repository.sent.single.$2, 'Keep this draft');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed first message retains its resolved session and draft', (
    tester,
  ) async {
    await pump(tester);
    repository.failSend = true;
    await enter(tester, 'Retry this message');
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters, {'sessionId': 'mock-new-1'});
    expect(
      tester.widget<ExtendedTextField>(input).controller!.text,
      'Retry this message',
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    repository.failSend = false;
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repository.resolutions, ['42']);
    expect(repository.creates, 1);
    expect(repository.sent.map((item) => item.$1), [
      'mock-new-1',
      'mock-new-1',
    ]);
    expect(tester.takeException(), isNull);
  });

  for (final leave in ['new', 'user']) {
    testWidgets('pending resolution is cancelled on $leave', (tester) async {
      await pump(tester);
      repository.pending = Completer<void>();
      await enter(tester, 'Do not send stale content');
      await tester.tap(send);
      await tester.pump();
      expect(repository.resolutions, ['42']);
      await tester.tap(send);
      expect(repository.resolutions, ['42']);
      if (leave == 'new') {
        await tester.tap(find.byKey(const Key('session-new-conversation')));
      } else {
        await container
            .read(userProvider.notifier)
            .setUser(const User(id: 'other', name: 'Other', email: ''));
      }
      await tester.pump();
      expect(repository.resolutionToken!.isCancelled, isTrue);
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(repository.sent, isEmpty);
      expect(repository.creates, 0);
      expect(tester.widget<ExtendedTextField>(input).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
