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
  final sent = <(String, String)>[];
  Completer<void>? pending;
  CancelToken? sendToken;
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
  Future<void> send(
    String userId,
    String id,
    String text,
    List<String> mediaIds, {
    List<String> roleIds = const [],
    CancelToken? cancelToken,
  }) async {
    sendToken = cancelToken;
    await pending?.future;
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    if (failSend) throw StateError('offline');
    sent.add((id, text));
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
      initialLocation: '/session?sessionId=existing-session',
      routes: [
        GoRoute(
          path: '/session',
          builder: (_, state) =>
              SessionPage(sessionId: state.uri.queryParameters['sessionId']),
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
    expect(repository.creates, 0);
  }

  testWidgets('first send uses the session bound during account creation', (
    tester,
  ) async {
    await pump(tester);
    await enter(tester, 'Create content for this account');
    await tester.tap(send);
    await tester.pumpAndSettle();
    const id = 'existing-session';
    expect(repository.creates, 0);
    expect(repository.sent, [(id, 'Create content for this account')]);
    expect(router.state.uri.queryParameters, {'sessionId': id});
    expect(tester.widget<ExtendedTextField>(input).controller!.text, isEmpty);
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
    expect(router.state.uri.queryParameters, {'sessionId': 'existing-session'});
    expect(
      tester.widget<ExtendedTextField>(input).controller!.text,
      'Retry this message',
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    repository.failSend = false;
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repository.creates, 0);
    expect(repository.sent.map((item) => item.$1), ['existing-session']);
    expect(tester.takeException(), isNull);
  });

  for (final leave in ['new', 'user']) {
    testWidgets('pending send is cancelled on $leave', (tester) async {
      await pump(tester);
      repository.pending = Completer<void>();
      await enter(tester, 'Do not send stale content');
      await tester.tap(send);
      await tester.pump();
      expect(repository.sendToken, isNotNull);
      await tester.tap(send);
      expect(repository.sent, isEmpty);
      if (leave == 'new') {
        await tester.tap(find.byKey(const Key('popi-open-navigation')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('drawer-new-session')));
      } else {
        await container
            .read(userProvider.notifier)
            .setUser(const User(id: 'other', name: 'Other', email: ''));
      }
      await tester.pump();
      expect(repository.sendToken!.isCancelled, isTrue);
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(repository.sent, isEmpty);
      expect(repository.creates, 0);
      expect(tester.widget<ExtendedTextField>(input).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
