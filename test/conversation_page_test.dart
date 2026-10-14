import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_skeleton.dart';

import 'conversation_controller_test.dart' show StreamingSessionRepository;
import 'conversation_events_test.dart'
    show chatId, chatEvent, chatMessageJson, chatSnapshotJson;

void main() {
  for (final (size, locale, dark, scale) in [
    (const Size(390, 844), const Locale('zh'), false, 1.0),
    (const Size(320, 844), const Locale('en'), true, 1.5),
    (const Size(1024, 768), const Locale('zh'), false, 1.0),
  ]) {
    testWidgets('progress header keeps the toggle next to text at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, Object?> progress(String state, int revision) => {
        ...chatMessageJson(seq: 3, revision: revision),
        'id': 'current-progress',
        'blocks': [
          {
            'type': 'object',
            'kind': 'progress',
            'data': {
              'runId': 'run',
              'state': state,
              'steps': [
                {'labelKey': 'script.run.preparing', 'status': 'completed'},
                {
                  'labelKey': 'script.run.processing',
                  'status': state == 'completed' ? 'completed' : 'running',
                },
              ],
            },
          },
        ],
      };
      final repository = StreamingSessionRepository()
        ..data = {
          ...chatSnapshotJson(
            seq: 1,
            messages: [
              {...progress('completed', 1), 'id': 'history', 'seq': 1},
              {
                ...chatMessageJson(seq: 2, text: 'Tell me a story'),
                'id': 'user-message',
                'role': 'user',
              },
            ],
          ),
          'runs': [
            {'id': 'run', 'state': 'running', 'purpose': 'consultation'},
          ],
        };
      final controller = ConversationController(repository, 'a')..open(chatId);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Scaffold(body: ConversationTimeline(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(locale);
      final loading = find.byType(CircularProgressIndicator);
      expect(find.text(l10n.chatThinking), findsOneWidget);
      expect(loading, findsNothing);
      var seq = 1;
      var revision = 0;
      for (final state in ['pending', 'started', 'running']) {
        repository.streams.single.add(
          chatEvent(++seq, 'message.updated', {
            'timelineUpdates': [progress(state, ++revision)],
          }),
        );
        await tester.pumpAndSettle();
        final current = find.byWidgetPredicate(
          (widget) =>
              widget is ConversationObjectView && widget.block.status == state,
        );
        expect(find.text(l10n.chatThinking), findsOneWidget);
        expect(loading, findsOneWidget);
        expect(find.descendant(of: current, matching: loading), findsOneWidget);
        final toggle = find.descendant(
          of: current,
          matching: find.byTooltip(l10n.chatCollapseProgress),
        );
        expect(
          tester.getTopLeft(toggle).dx -
              tester.getTopRight(find.text(l10n.chatThinking)).dx,
          inInclusiveRange(0, 8),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip(l10n.chatCollapseProgress).last);
      await tester.pumpAndSettle();
      expect(loading, findsNothing);
      expect(find.byTooltip(l10n.chatExpandProgress), findsOneWidget);
      repository.streams.single.add(
        chatEvent(++seq, 'run.completed', {
          'runId': 'run',
          'timelineUpdates': [progress('completed', ++revision)],
        }),
      );
      await tester.pumpAndSettle();
      expect(loading, findsNothing);
      expect(find.text(l10n.chatThinking), findsNothing);
      expect(find.text(l10n.chatCompleted), findsNWidgets(2));
      expect(find.byTooltip(l10n.chatExpandProgress), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final objectId in ['', 'shared-topic']) {
    testWidgets('browses repeated topic IDs "$objectId" through updates', (
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
      expect(find.text('Topic 1 revision 1'), findsNothing);
      final next = find.byKey(const Key('conversation-topic-next'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Topic 0 revision 1'), findsNothing);
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
      expect(find.text('Topic 0 revision 2'), findsNothing);
      expect(find.text('Topic 1 revision 2'), findsOneWidget);
      expect(
        tester.stateList(find.byType(ConversationObjectView)).toList(),
        orderedEquals(states),
      );
      await tester.tap(find.byKey(const Key('conversation-topic-previous')));
      await tester.pumpAndSettle();
      expect(find.text('Topic 0 revision 2'), findsOneWidget);
      expect(find.text('Topic 1 revision 2'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets(
      'opening message stays at the top of a short conversation at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const welcome = '这次想创作什么？可以说一个想法，或发来参考素材。';
        final repository = StreamingSessionRepository()
          ..data = chatSnapshotJson(
            seq: 1,
            messages: [chatMessageJson(text: welcome)],
          );
        final controller = ConversationController(repository, 'a')
          ..open(chatId);
        addTearDown(() async {
          controller.dispose();
          await repository.close();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ConversationTimeline(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
        final openingTop = tester.getTopLeft(find.text(welcome)).dy;
        final timelineTop = tester
            .getTopLeft(find.byType(ConversationTimeline))
            .dy;
        expect(openingTop - timelineTop, inInclusiveRange(10, 40));
        repository.streams.single.add(
          chatEvent(2, 'message.completed', {
            'timelineUpdates': [
              {
                ...chatMessageJson(seq: 2, text: 'A story idea'),
                'id': 'user-message',
                'role': 'user',
              },
            ],
          }),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text(welcome)).dy,
          closeTo(openingTop, 1),
        );
        expect(
          tester.getTopLeft(find.text('A story idea')).dy,
          greaterThan(openingTop),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('delayed history opens at the bottom at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = Completer<ConversationSnapshot>();
      final repository = StreamingSessionRepository()
        ..delayedSnapshot = snapshot;
      final controller = ConversationController(repository, 'a')..open(chatId);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConversationTimeline(controller: controller)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(find.byType(AppSkeletonBox), findsNWidgets(7));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      snapshot.complete(
        ConversationSnapshot.fromJson(
          chatSnapshotJson(
            seq: 41,
            messages: [
              for (var i = 0; i < 40; i++)
                {
                  ...chatMessageJson(
                    seq: i + 1,
                    text: List.filled(
                      1 + i % 6,
                      'History $i with a variable-height Markdown paragraph.',
                    ).join('\n\n'),
                  ),
                  'id': 'history-$i',
                },
              {
                ...chatMessageJson(seq: 41, text: 'Latest message'),
                'id': 'latest',
              },
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppSkeleton), findsOneWidget);
      final historyVisibility = find.ancestor(
        of: find.byType(Chat),
        matching: find.byType(Opacity),
      );
      var positioningFrames = 0;
      while (find.byType(AppSkeleton).evaluate().isNotEmpty) {
        expect(tester.widget<Opacity>(historyVisibility).opacity, 0);
        expect(find.text('Latest message').hitTestable(), findsNothing);
        expect(positioningFrames++, lessThan(100));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.widget<Opacity>(historyVisibility).opacity, 1);
      final latestTop = tester.getTopLeft(find.text('Latest message'));
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getTopLeft(find.text('Latest message')), latestTop);
      }
      await tester.pumpAndSettle();
      expect(find.byType(AppSkeleton), findsNothing);
      final list = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(list).position;
      double distanceFromBottom() => position.axisDirection == AxisDirection.up
          ? position.extentBefore
          : position.extentAfter;
      expect(position.maxScrollExtent, greaterThan(size.height));
      expect(distanceFromBottom(), closeTo(0, 1));
      expect(find.text('Latest message').hitTestable(), findsOneWidget);

      await tester.drag(list, const Offset(0, 600));
      await tester.pumpAndSettle();
      final historyOffset = position.pixels;
      expect(distanceFromBottom(), greaterThan(120));
      repository.streams.single.add(
        chatEvent(42, 'message.delta', {
          'messageId': 'latest',
          'delta': ' updated',
        }),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(historyOffset, 1));
      expect(distanceFromBottom(), greaterThan(120));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

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
