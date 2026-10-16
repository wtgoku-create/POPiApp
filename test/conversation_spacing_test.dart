import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

import 'conversation_controller_test.dart' show StreamingSessionRepository;
import 'conversation_events_test.dart'
    show chatId, chatMessageJson, chatSnapshotJson;

void main() {
  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('messages use 30 and adjacent cards use 10 at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = StreamingSessionRepository()
        ..data = chatSnapshotJson(
          messages: [
            {
              ...chatMessageJson(text: 'First request'),
              'id': 'user-1',
              'role': 'user',
            },
            {
              ...chatMessageJson(seq: 2),
              'id': 'progress',
              'blocks': [
                {
                  'type': 'object',
                  'kind': 'progress',
                  'data': {
                    'runId': 'run',
                    'state': 'completed',
                    'steps': [
                      {
                        'labelKey': 'script.run.processing',
                        'status': 'completed',
                      },
                    ],
                  },
                },
              ],
            },
            {
              ...chatMessageJson(seq: 3),
              'id': 'results',
              'blocks': [
                {'type': 'text', 'text': 'Progress reply'},
                for (final id in ['result-1', 'result-2'])
                  {
                    'type': 'object',
                    'kind': 'artifact',
                    'data': {'id': id, 'title': id, 'body': 'Result'},
                  },
              ],
            },
            {
              ...chatMessageJson(seq: 4, text: 'Next request'),
              'id': 'user-2',
              'role': 'user',
            },
            {...chatMessageJson(seq: 5, text: 'Reply'), 'id': 'reply'},
            {
              ...chatMessageJson(seq: 6, text: 'Another reply'),
              'id': 'reply-2',
            },
          ],
        );
      final controller = ConversationController(repository, 'user')
        ..open(chatId);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(body: ConversationTimeline(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      Finder text(String value) => find.byWidgetPredicate(
        (widget) => widget is MarkdownMessage && widget.text == value,
      );
      final progress = find.byWidgetPredicate(
        (widget) =>
            widget is ConversationObjectView && widget.block.kind == 'progress',
      );
      Finder result(String id) => find.byWidgetPredicate(
        (widget) => widget is ConversationObjectView && widget.block.id == id,
      );
      void checkGaps() {
        final firstBubble = tester.getRect(text('First request')).inflate(20);
        final nextBubble = tester.getRect(text('Next request')).inflate(20);
        expect(tester.getTopLeft(progress).dy - firstBubble.bottom, 30);
        expect(
          tester.getTopLeft(text('Progress reply')).dy -
              tester.getBottomLeft(progress).dy,
          10,
        );
        expect(
          tester.getTopLeft(result('result-1')).dy -
              tester.getBottomLeft(text('Progress reply')).dy,
          10,
        );
        expect(
          tester.getTopLeft(result('result-2')).dy -
              tester.getBottomLeft(result('result-1')).dy,
          10,
        );
        expect(
          nextBubble.top - tester.getBottomLeft(result('result-2')).dy,
          30,
        );
        expect(tester.getTopLeft(text('Reply')).dy - nextBubble.bottom, 30);
        expect(
          tester.getTopLeft(text('Another reply')).dy -
              tester.getBottomLeft(text('Reply')).dy,
          30,
        );
      }

      checkGaps();
      await tester.tap(find.byTooltip('收起进度'));
      await tester.pumpAndSettle();
      checkGaps();
      expect(tester.takeException(), isNull);
    });
  }
}
