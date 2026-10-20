import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'conversation_controller_test.dart' show StreamingSessionRepository;
import 'conversation_events_test.dart'
    show chatId, chatEvent, chatMessageJson, chatSnapshotJson;

StreamingSessionRepository _history() =>
    StreamingSessionRepository()
      ..data = chatSnapshotJson(
        seq: 20,
        messages: [
          for (var index = 0; index < 20; index++)
            {
              ...chatMessageJson(
                seq: index + 1,
                text: index == 19
                    ? 'Latest reply'
                    : List.filled(3, 'History $index paragraph.').join('\n\n'),
              ),
              'id': index == 19 ? 'latest' : 'history-$index',
            },
        ],
      );

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Finder _list() => find
    .descendant(
      of: find.byType(ConversationTimeline),
      matching: find.byType(CustomScrollView),
    )
    .first;

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: _list(), matching: find.byType(Scrollable)).first,
    )
    .position;

void main() {
  testWidgets('streaming follows layout changes and respects history reading', (
    tester,
  ) async {
    final repository = _history();
    final controller = ConversationController(repository, 'a')..open(chatId);
    final height = ValueNotifier(500.0);
    addTearDown(() async {
      controller.dispose();
      height.dispose();
      await repository.close();
    });
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (_, value, child) => Align(
              alignment: Alignment.topCenter,
              child: SizedBox(height: value, child: child),
            ),
            child: ConversationTimeline(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position = _position(tester);
    expect(position.extentAfter, closeTo(0, 1));
    var seq = 20;
    Future<void> delta(String text) async {
      repository.streams.single.add(
        chatEvent(++seq, 'message.delta', {
          'messageId': 'latest',
          'delta': text,
        }),
      );
      await tester.pumpAndSettle();
    }

    for (var index = 0; index < 4; index++) {
      await delta(List.filled(8, '\n\nStreaming paragraph $index.').join());
      expect(position.extentAfter, closeTo(0, 1));
    }
    height.value = 350;
    await tester.pumpAndSettle();
    expect(position.extentAfter, closeTo(0, 1));

    position.jumpTo(position.pixels - 200);
    await tester.pumpAndSettle();
    final revealedOffset = position.pixels;
    await delta('\n\nKeep programmatically revealed history visible.');
    expect(position.pixels, closeTo(revealedOffset, 1));
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    await tester.drag(_list(), const Offset(0, 400));
    await tester.pumpAndSettle();
    final readingOffset = position.pixels;
    expect(position.extentAfter, greaterThan(120));
    await delta('\n\nMore content while reading history.');
    expect(position.pixels, closeTo(readingOffset, 1));

    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    await delta('\n\nFollow the end again.');
    expect(position.extentAfter, closeTo(0, 1));

    await tester.drag(_list(), const Offset(0, 400));
    await tester.pumpAndSettle();
    repository.streams.single.add(
      chatEvent(++seq, 'message.updated', {
        'timelineUpdates': [
          {
            ...chatMessageJson(seq: 21, text: 'New user message'),
            'id': 'new-user',
            'role': 'user',
          },
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(position.extentAfter, closeTo(0, 1));
    expect(find.text('New user message').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(390, 844), const Size(320, 640)]) {
    testWidgets('latest reply stays above composer and keyboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final repository = _history();
      final container = ProviderContainer(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      container
          .read(safeAreaInsetsProvider.notifier)
          .update(const EdgeInsets.only(top: 24, bottom: 20));
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'a', name: 'User', email: ''));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _app(const SessionPage(sessionId: chatId)),
        ),
      );
      await tester.pumpAndSettle();
      final position = _position(tester);
      final composer = find.byKey(const Key('popi-composer-region-surface'));
      final feather = find.byKey(const Key('popi-composer-region-feather'));
      final input = find.byKey(const Key('popi-message-input'));
      void checkVisible() {
        expect(position.extentAfter, closeTo(0, 1));
        expect(
          tester.getBottomLeft(_list()).dy,
          closeTo(tester.getTopLeft(composer).dy, 1),
        );
        expect(
          tester.getBottomLeft(find.text('Latest reply')).dy,
          lessThanOrEqualTo(tester.getTopLeft(feather).dy + 1),
        );
        expect(find.text('Latest reply').hitTestable(), findsOneWidget);
      }

      checkVisible();
      await tester.tap(input);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      tester.testTextInput.enterText(
        'Line one\nLine two\nLine three\nLine four',
      );
      await tester.pumpAndSettle();
      checkVisible();
      tester.testTextInput.enterText('Short draft');
      await tester.pumpAndSettle();
      checkVisible();
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      checkVisible();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
