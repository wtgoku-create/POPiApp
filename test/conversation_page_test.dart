import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'conversation_controller_test.dart' show StreamingSessionRepository;
import 'conversation_events_test.dart'
    show chatId, chatEvent, chatMessageJson, chatSnapshotJson;

void main() {
  for (final objectId in ['', 'shared-topic']) {
    testWidgets('renders repeated object blocks with ID "$objectId"', (
      tester,
    ) async {
      Map<String, Object?> message(int revision, {bool insertText = false}) => {
        ...chatMessageJson(revision: revision),
        'blocks': [
          if (insertText) {'type': 'text', 'text': 'Updated topics'},
          for (var i = 0; i < 2; i++)
            {
              'type': 'object',
              'kind': 'topic',
              'data': {
                if (objectId.isNotEmpty) 'id': objectId,
                'title': 'Topic $i revision $revision',
              },
            },
        ],
      };
      final repository = StreamingSessionRepository()
        ..data = chatSnapshotJson(seq: 1, messages: [message(1)]);
      final container = ProviderContainer(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'a', name: 'User', email: ''));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SessionPage(sessionId: chatId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Topic 0 revision 1'), findsOneWidget);
      expect(find.text('Topic 1 revision 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final states = tester
          .stateList(find.byType(ConversationObjectView))
          .toList();

      repository.streams.first.add(
        chatEvent(2, 'message.updated', {
          'timelineUpdates': [message(2, insertText: true)],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Topic 0 revision 2'), findsOneWidget);
      expect(find.text('Topic 1 revision 2'), findsOneWidget);
      expect(
        tester.stateList(find.byType(ConversationObjectView)).toList(),
        orderedEquals(states),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets(
      'streams Markdown, stops and renders structured answers at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = StreamingSessionRepository();
        final container = ProviderContainer(
          overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(() async {
          container.dispose();
          await repository.close();
        });
        await container
            .read(userProvider.notifier)
            .setUser(const User(id: 'a', name: 'User', email: ''));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SessionPage(sessionId: chatId),
            ),
          ),
        );
        await tester.pumpAndSettle();
        repository.streams.first.add(
          chatEvent(2, 'message.delta', {
            'messageId': 'assistant',
            'delta': '**回复内容**',
          }),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('回复内容', findRichText: true), findsOneWidget);
        repository.streams.first.add(
          chatEvent(3, 'run.started', {
            'runId': 'run',
            'purpose': 'conversation',
          }),
        );
        // The run indicator deliberately animates until the backend finishes.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byTooltip('停止回复'), findsOneWidget);
        await tester.tap(find.byTooltip('停止回复'));
        await tester.pumpAndSettle();
        expect(repository.stops, 1);
        final message = chatMessageJson(revision: 2);
        message['blocks'] = [
          {
            'type': 'object',
            'kind': 'question',
            'data': {
              'id': 'question',
              'revision': 1,
              'title': '选择内容方向',
              'status': 'pending',
              'fields': [
                {
                  'id': 'topic',
                  'label': '内容方向',
                  'type': 'single_select',
                  'required': true,
                  'options': ['旅行', '美食'],
                },
              ],
            },
          },
        ];
        repository.streams.last.add(
          chatEvent(2, 'message.updated', {
            'timelineUpdates': [message],
          }),
        );
        await tester.pumpAndSettle();
        expect(find.text('选择内容方向'), findsOneWidget);
        expect(find.text('旅行'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), '自定义方向');
        await tester.pumpAndSettle();
        await tester.tap(find.text('旅行'));
        await tester.pump();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '确认'))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
