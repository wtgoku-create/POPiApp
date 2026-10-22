import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_selection_scope.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_task_card.dart';
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
  testWidgets(
    'selection handles stay inside the visible timeline',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(toolbarHeight: 96),
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 320,
                child: CustomScrollView(
                  controller: scroll,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(10),
                      sliver: SliverToBoxAdapter(
                        child: ConversationSelectionScope(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 12,
                            children: [
                              for (var i = 0; i < 30; i++)
                                // Keep Ahem's trailing caret inside its Text
                                // container so this tests viewport clipping.
                                Text(
                                  'Selection line $i',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final position = scroll.position;
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Selection line 0'));
      await tester.pumpAndSettle();
      final region = tester.state<SelectableRegionState>(
        find
            .ancestor(
              of: find.text('Selection line 0'),
              matching: find.byType(SelectableRegion),
            )
            .first,
      );
      region.selectAll(SelectionChangedCause.toolbar);
      await tester.pumpAndSettle();
      final overlay = region.selectionOverlay!;
      expect(overlay.startHandleLayerLink.leader, isNotNull);
      expect(
        overlay.endHandleLayerLink.leader,
        isNull,
        reason: 'The lower handle must not paint over the composer',
      );
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(overlay.startHandleLayerLink.leader, isNull);
      expect(overlay.endHandleLayerLink.leader, isNotNull);
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(overlay.startHandleLayerLink.leader, isNotNull);
      expect(overlay.endHandleLayerLink.leader, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'scrolling and reversing keeps every paragraph between the edges selected',
    (tester) async {
      String text(int i) =>
          'Block $i: ${List.filled(i % 3 + 1, 'Words that wrap onto several lines and stay selected.').join(' ')}';
      final repository = StreamingSessionRepository()
        ..data = chatSnapshotJson(
          messages: [
            chatMessageJson(text: List.generate(12, text).join('\n\n')),
          ],
        );
      final controller = ConversationController(repository, 'a')..open(chatId);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(),
            body: ConversationTimeline(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final position = _position(tester);
      RenderParagraph paragraph(int i) => tester.renderObject<RenderParagraph>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == text(i),
        ),
      );
      final delegate = tester
          .widget<SelectionContainer>(
            find
                .ancestor(
                  of: find.byType(MarkdownMessage).first,
                  matching: find.byType(SelectionContainer),
                )
                .first,
          )
          .delegate!;
      Offset point(int i, int offset) => paragraph(i).localToGlobal(
        paragraph(
              i,
            ).getOffsetForCaret(TextPosition(offset: offset), Rect.zero) +
            const Offset(1, 8),
      );
      position.jumpTo(0);
      await tester.pumpAndSettle();
      delegate.dispatchSelectionEvent(
        SelectWordSelectionEvent(globalPosition: point(3, 12)),
      );
      await tester.pump();
      final anchor = paragraph(3).selections.single.start;
      for (final (offset, end) in [
        (200.0, 6),
        (0.0, 1),
        (400.0, 7),
        (80.0, 2),
        (240.0, 5),
        (0.0, 0),
        (320.0, 6),
      ]) {
        position.jumpTo(offset.clamp(0, position.maxScrollExtent));
        await tester.pumpAndSettle();
        delegate.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forEnd(globalPosition: point(end, 15)),
        );
        await tester.pump();
        for (var i = end < 3 ? end + 1 : 4; i < (end < 3 ? 3 : end); i++) {
          expect(
            paragraph(i).selections.single,
            TextSelection(
              baseOffset: end < 3 ? text(i).length : 0,
              extentOffset: end < 3 ? 0 : text(i).length,
            ),
            reason: 'Gap in block $i, end=$end, offset=$offset',
          );
        }
        final selection = paragraph(3).selections.single;
        expect(
          end < 3 ? selection.end : selection.start,
          anchor,
          reason: 'The fixed anchor must not move with the viewport',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'selection and select all stay within the active reply',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repository = StreamingSessionRepository()
        ..data = chatSnapshotJson(
          messages: [
            {...chatMessageJson(text: 'Previous reply'), 'id': 'previous'},
            {
              ...chatMessageJson(seq: 2),
              'id': 'target',
              'blocks': [
                {
                  'type': 'text',
                  'text': 'Target first paragraph\n\nTarget second paragraph',
                },
                {'type': 'text', 'text': 'Target separate block'},
              ],
            },
            {
              ...chatMessageJson(seq: 3, text: 'Following reply'),
              'id': 'following',
            },
          ],
        );
      final controller = ConversationController(repository, 'a')..open(chatId);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      await tester.pumpWidget(
        _app(Scaffold(body: ConversationTimeline(controller: controller))),
      );
      await tester.pumpAndSettle();
      RenderParagraph paragraph(String text) =>
          tester.renderObject<RenderParagraph>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is RichText && widget.text.toPlainText() == text,
            ),
          );
      await tester.longPress(find.text('Target first paragraph'));
      await tester.pumpAndSettle();
      final target = paragraph('Target first paragraph');
      final box = target.getBoxesForSelection(target.selections.single).last;
      final gesture = await tester.startGesture(
        target.localToGlobal(box.toRect().bottomRight + const Offset(5, 8)),
      );
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesture.moveTo(tester.getBottomRight(find.text('Following reply')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(paragraph('Following reply').selections, isEmpty);
      expect(paragraph('Previous reply').selections, isEmpty);
      expect(paragraph('Target second paragraph').selections, isNotEmpty);
      SelectableRegionState regionFor(String text) =>
          tester.state<SelectableRegionState>(
            find
                .ancestor(
                  of: find.text(text),
                  matching: find.byType(SelectableRegion),
                )
                .first,
          );
      var region = regionFor('Target first paragraph');
      Future<void> selectAllAndCopy() async {
        region.selectAll(SelectionChangedCause.toolbar);
        await tester.pump();
        region.contextMenuButtonItems
            .firstWhere((item) => item.type == ContextMenuButtonType.copy)
            .onPressed!();
        await tester.pumpAndSettle();
      }

      await selectAllAndCopy();
      expect(copied, contains('Target first paragraph'));
      expect(copied, contains('Target second paragraph'));
      expect(copied, contains('Target separate block'));
      expect(copied, isNot(contains('Previous reply')));
      expect(copied, isNot(contains('Following reply')));
      await tester.longPress(find.text('Following reply'));
      await tester.pumpAndSettle();
      region = regionFor('Following reply');
      await selectAllAndCopy();
      expect(copied, contains('Following reply'));
      expect(copied, isNot(contains('Target')));
      expect(copied, isNot(contains('Previous reply')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'selection ignores retained cards outside the sliver layout',
    (tester) async {
      final repository = _history();
      final messages =
          repository.data['timelineMessages'] as List<Map<String, Object?>>;
      messages.insert(0, {
        ...chatMessageJson(seq: 0),
        'id': 'retained-task',
        'blocks': [
          {
            'type': 'object',
            'kind': 'task',
            'action': 'workflow',
            'data': {
              'id': 'task',
              'title': 'Retained production',
              'state': 'paused',
              'allowedActions': ['resume', 'cancel'],
              'steps': <Object>[],
            },
          },
        ],
      });
      final controller = ConversationController(repository, 'a')..open(chatId);
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      await tester.pumpWidget(
        _app(Scaffold(body: ConversationTimeline(controller: controller))),
      );
      await tester.pumpAndSettle();
      final position = _position(tester);
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        find.text('Retained production', skipOffstage: false),
        findsOneWidget,
      );
      final cardState = tester.state(find.byType(ConversationTaskCard));
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.text('Retained production', skipOffstage: false),
        findsOneWidget,
      );
      await tester.longPress(find.text('Latest reply'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Latest reply'),
          matching: find.byType(RichText),
        ),
      );
      expect(paragraph.selections, isNotEmpty);
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ConversationTaskCard)), same(cardState));
      await tester.longPress(find.text('Retained production'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final restored = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Retained production'),
          matching: find.byType(RichText),
        ),
      );
      expect(restored.selections, isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets('iOS selection handle scrolls the timeline and stops on release', (
    tester,
  ) async {
    String paragraphText(int index) => index == 39
        ? 'Final paragraph.'
        : 'Paragraph $index with selectable text. '
              '${List.filled(index % 3 + 1, 'A wrapped paragraph keeps its text selected while the direction changes.').join(' ')}';
    final repository = StreamingSessionRepository()
      ..data = chatSnapshotJson(
        messages: [
          chatMessageJson(text: List.generate(40, paragraphText).join('\n\n')),
        ],
      );
    final controller = ConversationController(repository, 'a')..open(chatId);
    addTearDown(() async {
      controller.dispose();
      await repository.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(toolbarHeight: 96),
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 390,
              height: 400,
              child: ConversationTimeline(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position = _position(tester);
    position.jumpTo(200);
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText() == paragraphText(10),
      ),
    );
    position.jumpTo(
      position.pixels +
          paragraph.localToGlobal(Offset.zero).dy -
          tester.getTopLeft(_list()).dy -
          120,
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      paragraph.localToGlobal(
        paragraph.getOffsetForCaret(const TextPosition(offset: 15), Rect.zero) +
            const Offset(0, 8),
      ),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(paragraph.selections, isNotEmpty);
    final box = paragraph
        .getBoxesForSelection(paragraph.selections.single)
        .last;
    await gesture.down(paragraph.localToGlobal(box.toRect().bottomRight));
    await gesture.moveTo(
      Offset(
        tester.getCenter(_list()).dx,
        tester.getBottomLeft(_list()).dy + 40,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(position.pixels, greaterThan(0));
    final firstOffset = position.pixels;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(position.pixels, greaterThan(firstOffset));
    const targetIndex = 10;
    await gesture.moveTo(
      Offset(tester.getCenter(_list()).dx, tester.getTopLeft(_list()).dy - 40),
    );
    for (var frame = 0; frame < 200 && position.pixels > 0; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.moveTo(
      tester.getTopLeft(find.text(paragraphText(0))) + const Offset(1, 8),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    for (var index = 0; index <= targetIndex; index++) {
      final selectedParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text(paragraphText(index)),
          matching: find.byType(RichText),
        ),
      );
      expect(
        selectedParagraph.selections,
        isNotEmpty,
        reason: 'Paragraph $index must not become a gap after reversing',
      );
      expect(selectedParagraph.selections.single.start, 0);
      if (index < targetIndex) {
        expect(
          selectedParagraph.selections.single.end,
          paragraphText(index).length,
          reason: 'Every intermediate paragraph must be fully selected',
        );
      }
    }
    final stoppedOffset = position.pixels;
    await tester.pump(const Duration(seconds: 1));
    expect(position.pixels, stoppedOffset);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final lastText = find.text(paragraphText(39));
    await tester.longPress(lastText);
    await tester.pumpAndSettle();
    final lastParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: lastText, matching: find.byType(RichText)),
    );
    final startBox = lastParagraph
        .getBoxesForSelection(lastParagraph.selections.single)
        .first;
    await gesture.down(
      lastParagraph.localToGlobal(startBox.toRect().bottomLeft),
    );
    await gesture.moveTo(
      Offset(tester.getCenter(_list()).dx, tester.getTopLeft(_list()).dy - 40),
    );
    final bottomOffset = position.pixels;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(position.pixels, lessThan(bottomOffset));
    await gesture.up();
    await tester.pumpAndSettle();
    final upwardStoppedOffset = position.pixels;
    await tester.pump(const Duration(seconds: 1));
    expect(position.pixels, upwardStoppedOffset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
