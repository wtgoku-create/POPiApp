import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card_content.dart';

void main() {
  testWidgets('a fling at the card boundary continues in the conversation', (
    tester,
  ) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: outer,
            children: const [
              ConversationCardContent(
                storageId: 'fling',
                child: SizedBox(height: 1000),
              ),
              SizedBox(height: 3000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byType(ConversationCardContent);
    final inner = tester
        .state<ScrollableState>(
          find.descendant(of: card, matching: find.byType(Scrollable)).first,
        )
        .position;
    inner.jumpTo(inner.maxScrollExtent);
    await tester.fling(card, const Offset(0, -80), 1200);
    final releasedOffset = outer.offset;
    await tester.pumpAndSettle();
    expect(outer.offset, greaterThan(releasedOffset + 30));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    testWidgets(
      'card content fits short documents and scrolls long ones at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final outer = ScrollController();
        addTearDown(outer.dispose);
        Future<void> pump(Widget child) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ListView(
                  controller: outer,
                  children: [
                    const Text('Document'),
                    ConversationCardContent(
                      storageId: 'document',
                      child: child,
                    ),
                    TextButton(onPressed: () {}, child: const Text('Confirm')),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pump(const SizedBox(height: 48, child: Text('Short content')));
        final content = find.byType(ConversationCardContent);
        expect(tester.getSize(content).height, 48);
        await tester.drag(content, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(outer.offset, greaterThan(0));
        outer.jumpTo(0);
        await pump(
          Column(
            children: [
              for (var index = 0; index < 30; index++)
                SizedBox(height: 48, child: Text('Paragraph $index')),
            ],
          ),
        );
        expect(tester.getSize(content).height, lessThanOrEqualTo(320));
        expect(find.text('Confirm').hitTestable(), findsOneWidget);
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: content, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(content, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        expect(outer.offset, 0);
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        expect(find.text('Paragraph 29').hitTestable(), findsOneWidget);
        await tester.drag(content, const Offset(0, -80));
        await tester.pumpAndSettle();
        expect(outer.offset, greaterThan(0));
        expect(position.pixels, position.maxScrollExtent);

        outer.jumpTo(80);
        position.jumpTo(20);
        await tester.pump();
        // A single drag consumes the remaining card content, then the list.
        await tester.drag(content, const Offset(0, 70));
        await tester.pumpAndSettle();
        expect(position.pixels, 0);
        expect(outer.offset, lessThan(80));

        outer.jumpTo(80);
        await tester.pump();
        await tester.drag(content, const Offset(0, 60));
        await tester.pumpAndSettle();
        expect(outer.offset, lessThan(80));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('embedded content shares its enclosing card viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConversationCardContent(
            storageId: 'outer',
            child: ConversationCardContent(
              storageId: 'embedded',
              child: SizedBox(height: 1000),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
