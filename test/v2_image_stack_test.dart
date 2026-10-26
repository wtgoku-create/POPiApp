import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_fixtures.dart';
import 'package:popi_ai_app/features/v2_session/presentation/widgets/v2_image_stack.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

Future<void> _pumpDeck(
  WidgetTester tester,
  List<int> changes, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: V2ImageStack(
              images: V2Fixtures.assets()
                  .where((asset) => asset.id.startsWith('scene'))
                  .toList(),
              messageId: 'deck-test',
              initialIndex: 0,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _card(int number) => find.byKey(ValueKey('deck-card-scene$number'));

Finder _image(int number) =>
    find.descendant(of: _card(number), matching: find.byType(Image));

List<Key?> _paintOrder(WidgetTester tester) => tester
    .widget<Stack>(find.byType(Stack).first)
    .children
    .map((child) => child.key)
    .toList();

void main() {
  testWidgets('card clears the deck before changing sides in both directions', (
    tester,
  ) async {
    final changes = <int>[];
    await _pumpDeck(tester, changes);
    final deck = find.byType(V2ImageStack);
    final size = tester.getSize(deck);
    final origin = tester.getTopLeft(_image(1));
    final gesture = await tester.startGesture(tester.getCenter(deck));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-265, 0));
    await tester.pump();
    expect(tester.getTopLeft(_image(1)).dx, lessThan(origin.dx - 200));
    expect(_paintOrder(tester).last, const ValueKey('deck-card-scene1'));
    expect(changes, isEmpty);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(_paintOrder(tester).first, const ValueKey('deck-card-scene1'));
    expect(changes, isEmpty);
    await tester.pumpAndSettle();
    expect(changes, [1]);
    expect(find.text('2/5'), findsOneWidget);
    expect(tester.getSize(deck), size);

    final reverse = await tester.startGesture(tester.getCenter(deck));
    await reverse.moveBy(const Offset(20, 0));
    await reverse.moveBy(const Offset(265, 0));
    await tester.pump();
    expect(tester.getTopLeft(_image(1)).dx, greaterThan(origin.dx + 200));
    expect(_paintOrder(tester).first, const ValueKey('deck-card-scene1'));
    await reverse.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(_paintOrder(tester).last, const ValueKey('deck-card-scene1'));
    await tester.pumpAndSettle();
    expect(changes, [1, 0]);
    expect(tester.getTopLeft(_image(1)), origin);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled drag returns the card without changing selection', (
    tester,
  ) async {
    final changes = <int>[];
    await _pumpDeck(tester, changes);
    final origin = tester.getTopLeft(_image(1));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(V2ImageStack)),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-70, 0));
    await tester.pump();
    expect(tester.getTopLeft(_image(1)).dx, lessThan(origin.dx));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_image(1)), origin);
    expect(changes, isEmpty);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('reduced motion changes selection without a settling animation', (
    tester,
  ) async {
    final changes = <int>[];
    await _pumpDeck(tester, changes, reduceMotion: true);
    await tester.drag(find.byType(V2ImageStack), const Offset(-220, 0));
    await tester.pump();
    expect(changes, [1]);
    expect(find.text('2/5'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
