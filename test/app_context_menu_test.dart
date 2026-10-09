import 'dart:ui' show PointerDeviceKind;

import 'package:cupertino_context_menu_plus/cupertino_context_menu_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_menu.dart';
import 'package:popi_ai_app/shared/widgets/app_modal_backdrop.dart';

void main() {
  Future<void> pumpMenu(
    WidgetTester tester,
    VoidCallback onTap, {
    bool enabled = true,
    bool reduceMotion = false,
    Size size = const Size(320, 568),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: AppContextMenu(
              label: 'Row options',
              enabled: enabled,
              entries: [AppMenuItem(label: 'Rename', onSelected: () {})],
              child: InkWell(
                key: const Key('row'),
                onTap: onTap,
                child: const SizedBox(
                  width: 200,
                  height: 42,
                  child: Text('Row'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long press opens within viewport without invoking the row tap', (
    tester,
  ) async {
    var taps = 0;
    await pumpMenu(tester, () => taps++);
    await tester.longPress(find.byKey(const Key('row')));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(find.byType(CupertinoContextMenuPlus), findsOneWidget);
    expect(find.byKey(const Key('app-context-menu-preview')), findsOneWidget);
    expect(find.byKey(const Key('app-context-menu-panel')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final menu = tester.widget<CupertinoContextMenuPlus>(
      find.byType(CupertinoContextMenuPlus),
    );
    expect(menu.showGrowAnimation, isTrue);
    expect(menu.backdropBlurSigma, AppModalBackdrop.blurSigma);
    expect(menu.barrierColor, AppModalBackdrop.dimColor);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-context-menu-panel')),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(menu.modalTransitionDuration, const Duration(milliseconds: 260));
    final rect = tester.getRect(find.text('Rename'));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.bottom, lessThanOrEqualTo(568));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    await tester.tap(find.byKey(const Key('row')));
    expect(taps, 1);
  });

  testWidgets('preview actions close before callbacks can remove the source', (
    tester,
  ) async {
    var selected = false;
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, value, __) => value
                ? AppContextMenu(
                    label: 'Options',
                    entries: [
                      AppMenuItem(
                        label: 'Remove',
                        onSelected: () {
                          selected = true;
                          visible.value = false;
                        },
                      ),
                    ],
                    child: const SizedBox(
                      width: 200,
                      height: 42,
                      child: Text('Source'),
                    ),
                  )
                : const Text('Removed'),
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pump(const Duration(milliseconds: 90));
    expect(selected, isFalse);
    expect(find.byKey(const Key('app-context-menu-preview')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('Removed'), findsOneWidget);
    expect(find.byKey(const Key('app-context-menu-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding lifts the preview before the menu animates into place', (
    tester,
  ) async {
    var taps = 0;
    await pumpMenu(tester, () => taps++);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('row'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final preview = find.byKey(const Key('app-context-menu-preview'));
    expect(tester.getSize(preview).width, greaterThan(200));
    expect(find.byKey(const Key('app-context-menu-panel')), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final openingRect = tester.getRect(preview);
    await tester.pumpAndSettle();
    expect(tester.getRect(preview), isNot(openingRect));
    await gesture.up();
    expect(taps, 0);
    expect(find.text('Rename'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    final shortPress = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('row'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await shortPress.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('Rename'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing an open preview cleans up its route', (tester) async {
    await pumpMenu(tester, () {});
    await tester.longPress(find.byKey(const Key('row')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion disables growth and visible route transitions', (
    tester,
  ) async {
    await pumpMenu(tester, () {}, reduceMotion: true);
    await tester.longPress(find.byKey(const Key('row')));
    await tester.pumpAndSettle();
    final menu = tester.widget<CupertinoContextMenuPlus>(
      find.byType(CupertinoContextMenuPlus),
    );
    expect(menu.showGrowAnimation, isFalse);
    expect(menu.modalTransitionDuration, const Duration(microseconds: 1));
    expect(
      menu.modalReverseTransitionDuration,
      const Duration(microseconds: 1),
    );
    expect(find.text('Rename'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
  });

  testWidgets('preview menus retain styled submenus and scroll long lists', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppContextMenu(
            label: 'Options',
            entries: [
              AppSubmenu(
                label: 'Export',
                entries: [
                  AppMenuItem(label: 'PNG', onSelected: () => selected = true),
                ],
              ),
            ],
            child: const SizedBox(
              width: 200,
              height: 42,
              child: Text('Source'),
            ),
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PNG'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('PNG'), findsNothing);
    expect(find.byKey(const Key('app-context-menu-preview')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppContextMenu(
            label: 'Options',
            entries: [
              for (var index = 0; index < 30; index++)
                AppMenuItem(label: 'Action $index', onSelected: () {}),
            ],
            child: const SizedBox(
              width: 200,
              height: 42,
              child: Text('Source'),
            ),
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Source'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Action 29'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('app-context-menu-panel')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Action 29'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-context-menu-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right click opens and platform back closes only the menu', (
    tester,
  ) async {
    var taps = 0;
    await pumpMenu(tester, () => taps++);
    await tester.tap(
      find.byKey(const Key('row')),
      kind: PointerDeviceKind.mouse,
      buttons: 2,
    );
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(taps, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Row'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard and disabled context menus behave consistently', (
    tester,
  ) async {
    await pumpMenu(tester, () {});
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    await pumpMenu(tester, () {}, enabled: false);
    await tester.longPress(find.byKey(const Key('row')));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
