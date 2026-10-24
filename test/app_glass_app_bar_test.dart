import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_glass_app_bar.dart';

void main() {
  for (final dark in [false, true]) {
    for (final custom in [false, true]) {
      testWidgets(
        'compact glass preserves header bounds and inputs: dark=$dark custom=$custom',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 62);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final header = SizedBox(
            key: const Key('custom-header'),
            height: 110,
            child: const Padding(
              padding: EdgeInsets.only(top: 62),
              child: Center(child: Text('Profile')),
            ),
          );
          final input = TextField(key: const Key('search'));
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: Scaffold(
                appBar: custom
                    ? null
                    : AppGlassAppBar(
                        extendBackdrop: false,
                        child: AppBar(
                          toolbarHeight: 48,
                          title: const Text('Profile'),
                        ),
                      ),
                body: Column(
                  children: [
                    if (custom) AppGlassHeader(child: header),
                    input,
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final glass = find.byType(BackdropFilter);
          expect(tester.getSize(glass), const Size(390, 110));
          final search = find.byKey(const Key('search'));
          expect(tester.getRect(search).top, 110);
          await tester.tap(search);
          await tester.enterText(search, 'POPi');
          await tester.pumpAndSettle();
          expect(find.text('POPi'), findsOneWidget);
          if (!custom) {
            final surface = find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            );
            expect(
              tester.widget<Material>(surface.first).color,
              Colors.transparent,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('top glass keeps navigation and scrolling usable: dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 62);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var backTaps = 0;
      var rowTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppGlassAppBar(
              child: AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  key: const Key('back'),
                  onPressed: () => backTaps++,
                  icon: const Icon(Icons.arrow_back),
                ),
                title: const Text('Conversation'),
              ),
            ),
            body: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.only(top: 128),
              itemExtent: 80,
              itemCount: 100,
              itemBuilder: (context, index) => TextButton(
                key: ValueKey(index),
                onPressed: () => rowTaps++,
                child: Text('Message $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byType(AppBar));
      expect(bar.top, 0);
      expect(bar.height, 62 + kToolbarHeight);
      final glass = find
          .descendant(
            of: find.byType(AppGlassAppBar),
            matching: find.byType(BackdropFilter),
          )
          .first;
      expect(tester.getSize(glass), const Size(440, 166));
      final decoration = tester.widget<DecoratedBox>(
        find.descendant(of: glass, matching: find.byType(DecoratedBox)).first,
      );
      final gradient = (decoration.decoration as BoxDecoration).gradient!;
      expect(gradient.stops, [.4, .6, 1]);
      expect(gradient.colors.last.a, 0);
      expect(tester.getRect(find.byKey(const ValueKey(0))).top, 128);
      // The fading glass overlaps this row without intercepting its taps.
      await tester.tapAt(const Offset(220, 145));
      expect(rowTaps, 1);
      scroll.jumpTo(100);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey(0))).top,
        lessThan(bar.bottom),
      );
      await tester.tap(find.byKey(const Key('back')));
      expect(backTaps, 1);
      expect(tester.getRect(find.byType(AppBar)), bar);
      expect(tester.takeException(), isNull);
    });
  }
}
