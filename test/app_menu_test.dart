import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_menu.dart';

void main() {
  Future<void> pumpMenu(
    WidgetTester tester, {
    required List<AppMenuEntry> entries,
    ThemeData? theme,
    Size size = const Size(440, 956),
    double textScale = 1,
    bool enabled = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppMenuButton(
                key: const Key('menu'),
                tooltip: 'Options',
                entries: entries,
                enabled: enabled,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('actions close the menu and outside taps do not select actions', (
    tester,
  ) async {
    var selections = 0;
    await pumpMenu(
      tester,
      entries: [AppMenuItem(label: 'Run', onSelected: () => selections++)],
    );
    expect(find.text('Run'), findsNothing);
    await openMenu(tester);
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();
    expect(find.text('Run'), findsNothing);
    expect(selections, 0);

    await openMenu(tester);
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(selections, 1);
    expect(find.text('Run'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested actions close the entire menu hierarchy', (tester) async {
    var selections = 0;
    await pumpMenu(
      tester,
      entries: [
        AppSubmenu(
          label: 'Project',
          entries: [
            AppSubmenu(
              label: 'Export',
              entries: [
                AppMenuItem(label: 'PNG', onSelected: () => selections++),
              ],
            ),
          ],
        ),
      ],
    );
    await openMenu(tester);
    expect(find.text('Export'), findsNothing);
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PNG'));
    await tester.pumpAndSettle();
    expect(selections, 1);
    expect(find.text('Project'), findsNothing);
    expect(find.text('Export'), findsNothing);
    expect(find.text('PNG'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labels align with leading checks and trailing action icons', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      entries: [
        AppMenuItem(
          key: const Key('current-item'),
          label: 'Current',
          selected: true,
          icon: const Icon(Icons.download, key: Key('action-icon')),
          onSelected: () {},
        ),
        AppMenuItem(label: 'Other', onSelected: () {}),
        AppSubmenu(
          label: 'Project',
          icon: const Icon(Icons.folder_outlined, key: Key('submenu-icon')),
          entries: [
            AppMenuItem(
              label: 'Export',
              icon: const Icon(Icons.download, key: Key('nested-icon')),
              onSelected: () {},
            ),
          ],
        ),
      ],
    );
    await openMenu(tester);
    final current = tester.getRect(find.text('Current'));
    expect(
      tester.getRect(find.byIcon(Icons.check)).right,
      lessThan(current.left),
    );
    expect(
      tester.getRect(find.byKey(const Key('action-icon'))).left,
      greaterThan(current.right),
    );
    expect(tester.getRect(find.text('Other')).left, current.left);
    expect(tester.getRect(find.text('Project')).left, current.left);
    expect(
      tester.getSize(find.byKey(const Key('current-item'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getRect(find.byKey(const Key('submenu-icon'))).left,
      greaterThan(tester.getRect(find.text('Project')).right),
    );
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('nested-icon'))).left,
      greaterThan(tester.getRect(find.text('Export')).right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('menus show and dismiss immediately without blurred surfaces', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      entries: [
        AppSubmenu(
          label: 'Project',
          entries: [AppMenuItem(label: 'Export', onSelected: () {})],
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('menu')));
    await tester.pump();
    expect(find.text('Project').hitTestable(), findsOneWidget);
    final rootFade = find.ancestor(
      of: find.text('Project'),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(rootFade.first).opacity.value, 1);
    final rootRect = tester.getRect(find.text('Project'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(find.text('Project')), rootRect);

    await tester.tap(find.text('Project'));
    await tester.pump();
    expect(find.text('Export').hitTestable(), findsOneWidget);
    final childFade = find.ancestor(
      of: find.text('Export'),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(childFade.first).opacity.value, 1);
    final childRect = tester.getRect(find.text('Export'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(find.text('Export')), childRect);
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('Export'));
    await tester.pump();
    expect(find.text('Export'), findsNothing);
    expect(find.text('Project'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled items and submenus cannot activate', (tester) async {
    var selections = 0;
    await pumpMenu(
      tester,
      entries: [
        AppMenuItem(
          label: 'Disabled',
          enabled: false,
          onSelected: () => selections++,
        ),
        const AppMenuItem(label: 'Unavailable', onSelected: null),
        AppSubmenu(
          label: 'Locked',
          enabled: false,
          entries: [
            AppMenuItem(label: 'Hidden', onSelected: () => selections++),
          ],
        ),
        const AppSubmenu(label: 'Empty', entries: []),
      ],
    );
    await openMenu(tester);
    for (final label in ['Disabled', 'Unavailable', 'Locked', 'Empty']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(selections, 0);
    expect(find.text('Hidden'), findsNothing);
    expect(find.text('Disabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and disabled triggers do not open', (tester) async {
    await pumpMenu(tester, entries: const []);
    final button = find.descendant(
      of: find.byKey(const Key('menu')),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    await pumpMenu(
      tester,
      enabled: false,
      entries: [AppMenuItem(label: 'Run', onSelected: () {})],
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);
  });

  testWidgets('platform back closes the menu before leaving the page', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      entries: [AppMenuItem(label: 'Run', onSelected: () {})],
    );
    await openMenu(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Run'), findsNothing);
    expect(find.byKey(const Key('menu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mouse hover opens submenus and Escape dismisses them', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      entries: [
        AppSubmenu(
          label: 'Project',
          entries: [AppMenuItem(label: 'Export', onSelected: () {})],
        ),
      ],
    );
    await openMenu(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 500));
    await mouse.moveTo(tester.getCenter(find.text('Project')));
    await tester.pumpAndSettle();
    expect(find.text('Export'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Export'), findsNothing);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard can open a menu and select an action', (tester) async {
    var selections = 0;
    await pumpMenu(
      tester,
      entries: [AppMenuItem(label: 'Run', onSelected: () => selections++)],
    );
    final button = find.descendant(
      of: find.byKey(const Key('menu')),
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(button).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Run'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selections, 1);
    expect(find.text('Run'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard can navigate into a submenu', (tester) async {
    var selections = 0;
    await pumpMenu(
      tester,
      entries: [
        AppSubmenu(
          label: 'Project',
          entries: [
            AppMenuItem(label: 'Export', onSelected: () => selections++),
          ],
        ),
      ],
    );
    final button = find.descendant(
      of: find.byKey(const Key('menu')),
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(button).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Export'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selections, 1);
    expect(find.text('Project'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long menu scrolls to actions within the viewport', (
    tester,
  ) async {
    int? selection;
    await pumpMenu(
      tester,
      size: const Size(320, 568),
      entries: [
        for (var index = 0; index < 30; index++)
          AppMenuItem(
            label: 'Action $index',
            onSelected: () => selection = index,
          ),
      ],
    );
    await openMenu(tester);
    await tester.scrollUntilVisible(
      find.text('Action 29'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Action 29'));
    await tester.pumpAndSettle();
    expect(selection, 29);
    expect(find.text('Action 29'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('root and submenu match the ${dark ? 'dark' : 'light'} theme', (
      tester,
    ) async {
      final theme = dark ? AppTheme.dark : AppTheme.light;
      final surface = dark
          ? theme.colorScheme.surfaceContainerHigh
          : theme.colorScheme.surface;
      await pumpMenu(
        tester,
        theme: theme,
        entries: [
          AppMenuItem(label: 'Current', selected: true, onSelected: () {}),
          const AppMenuDivider(),
          AppMenuItem(label: 'Delete', destructive: true, onSelected: () {}),
          AppSubmenu(
            label: 'Project',
            entries: [AppMenuItem(label: 'Export', onSelected: () {})],
          ),
        ],
      );
      await openMenu(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);
      final deleteText = tester.element(find.text('Delete'));
      expect(
        DefaultTextStyle.of(deleteText).style.color,
        theme.colorScheme.error,
      );
      await tester.tap(find.text('Project'));
      await tester.pumpAndSettle();
      for (final label in ['Current', 'Export']) {
        final panels = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material &&
                widget.color == surface &&
                widget.elevation == 3 &&
                widget.shape is RoundedRectangleBorder,
          ),
        );
        expect(panels, findsWidgets);
        final panel = tester.widget<Material>(panels.first);
        expect(
          (panel.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(20),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('long labels fit a compact ${dark ? 'dark' : 'light'} menu', (
      tester,
    ) async {
      const parentLabel = 'More options for the current IP project';
      const childLabel =
          'Export the current project and its conversation history';
      await pumpMenu(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        theme: dark ? AppTheme.dark : AppTheme.light,
        entries: [
          AppSubmenu(
            label: parentLabel,
            entries: [AppMenuItem(label: childLabel, onSelected: () {})],
          ),
        ],
      );
      await openMenu(tester);
      await tester.tap(find.text(parentLabel));
      await tester.pumpAndSettle();
      for (final label in [parentLabel, childLabel]) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.bottom, lessThanOrEqualTo(568));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('removing an open menu clears its route history', (tester) async {
    await pumpMenu(
      tester,
      entries: [AppMenuItem(label: 'Run', onSelected: () {})],
    );
    await openMenu(tester);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();
    expect(find.text('Run'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
