import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_dialog.dart';
import 'package:popi_ai_app/shared/widgets/app_menu.dart';
import 'package:popi_ai_app/shared/widgets/app_modal_backdrop.dart';
import 'package:popi_ai_app/shared/widgets/app_modal_scope.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';

const _preview = Key('app-context-menu-preview');

class _Fixture {
  _Fixture({this.includeMenu = false});

  final bool includeMenu;
  final navigator = GlobalKey<NavigatorState>();
  final active = ValueNotifier(true);
  late BuildContext source;
  int sidebarTaps = 0;
  String? result;
  bool completed = false;
  int menuSelections = 0;

  void dispose() => active.dispose();

  Future<void> open(String kind, {bool useRootNavigator = false}) async {
    completed = false;
    if (kind == 'Dialog') {
      result = await AppDialog.show<String>(
        context: source,
        useRootNavigator: useRootNavigator,
        builder: (context) => AppDialog(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop('confirmed'),
            child: const Text('Confirm'),
          ),
        ),
      );
    } else {
      result = await AppSheet.show<String>(
        context: source,
        builder: (context) => SizedBox(
          height: 200,
          child: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop('confirmed'),
              child: const Text('Confirm'),
            ),
          ),
        ),
      );
    }
    completed = true;
  }

  Widget page(BuildContext context) {
    source = context;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in ['Dialog', 'Sheet'])
              TextButton(onPressed: () => open(kind), child: Text(kind)),
            AppContextMenu(
              label: 'Options',
              entries: [
                AppMenuItem(label: 'Edit', onSelected: () => open('Dialog')),
              ],
              child: const SizedBox(
                width: 180,
                height: 42,
                child: Center(child: Text('Source')),
              ),
            ),
            if (includeMenu)
              AppMenuButton(
                tooltip: 'Menu',
                entries: [
                  AppMenuItem(
                    label: 'A long global menu action',
                    onSelected: () => menuSelections++,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, {double sidebarWidth = 320}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: [AppModalObserver()],
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: sidebarWidth,
                child: Center(
                  child: TextButton(
                    onPressed: () => sidebarTaps++,
                    child: const Text('Sidebar'),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(size: constraints.biggest),
                    child: ClipRect(
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: active,
                        builder: (context, value, child) => Offstage(
                          offstage: !value,
                          child: TickerMode(
                            enabled: value,
                            child: AppModalScope(active: value, child: child!),
                          ),
                        ),
                        child: NavigatorPopHandler<void>(
                          onPopWithResult: (_) =>
                              navigator.currentState!.maybePop(),
                          child: Navigator(
                            key: navigator,
                            observers: [AppModalObserver()],
                            onGenerateRoute: (_) =>
                                MaterialPageRoute<void>(builder: page),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, String kind) async {
    if (kind == 'Context') {
      await tester.longPress(find.text('Source'));
    } else {
      await tester.tap(find.text(kind));
    }
    await tester.pumpAndSettle();
  }
}

void main() {
  if (kIsWeb) {
    _webTests();
    return;
  }
  testWidgets(
    'global dialogs cover both panes and close with their own result',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      fixture.open('Dialog', useRootNavigator: true);
      await tester.pumpAndSettle();
      final content = find.text('Confirm');
      expect(
        Navigator.of(tester.element(content)),
        isNot(fixture.navigator.currentState),
      );
      expect(
        tester.getRect(find.byType(AppModalBackdrop)),
        const Rect.fromLTWH(0, 0, 1000, 700),
      );
      expect(tester.getRect(find.byType(AppDialog)).center.dx, 500);
      await tester.tapAt(tester.getCenter(find.text('Sidebar')));
      await tester.pumpAndSettle();
      expect(fixture.sidebarTaps, 0);
      expect(fixture.completed, isTrue);
      expect(fixture.result, isNull);

      fixture.open('Dialog', useRootNavigator: true);
      await tester.pumpAndSettle();
      await tester.tap(content);
      await tester.pumpAndSettle();
      expect(fixture.result, 'confirmed');
      expect(find.text('Source').hitTestable(), findsOneWidget);
      expect(fixture.navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('global confirmations keep their source pane lifecycle binding', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    final result = AppDialog.confirm(
      context: fixture.source,
      useRootNavigator: true,
      title: 'Delete?',
      description: 'Delete this item?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppModalBackdrop)).left, 0);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    fixture.open('Dialog', useRootNavigator: true);
    await tester.pumpAndSettle();
    fixture.active.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
    expect(fixture.completed, isTrue);
    expect(fixture.result, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final kind in ['Dialog', 'Sheet', 'Context']) {
    testWidgets(
      '$kind stays in its pane across resizing and allows sidebar taps',
      (tester) async {
        final fixture = _Fixture();
        await fixture.pump(tester);
        await fixture.show(tester, kind);
        final content = kind == 'Context'
            ? find.byKey(_preview)
            : find.text('Confirm');
        expect(
          Navigator.of(tester.element(content)),
          fixture.navigator.currentState,
        );
        final blur = find.byType(BackdropFilter);
        expect(tester.getRect(blur), const Rect.fromLTWH(320, 0, 680, 700));
        expect(tester.getRect(content).left, greaterThanOrEqualTo(320));
        await tester.tap(find.text('Sidebar'));
        await tester.pumpAndSettle();
        expect(fixture.sidebarTaps, 1);
        expect(content, findsOneWidget);

        tester.view.physicalSize = const Size(760, 520);
        await tester.pumpAndSettle();
        expect(tester.getRect(blur), const Rect.fromLTWH(320, 0, 440, 520));
        expect(tester.getRect(content).left, greaterThanOrEqualTo(320));
        expect(tester.getRect(content).right, lessThanOrEqualTo(760));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(blur, findsNothing);
        expect(find.text('Source').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$kind is removed when its retained pane becomes hidden', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await fixture.show(tester, kind);
      fixture.active.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter, skipOffstage: false), findsNothing);
      expect(find.byKey(_preview, skipOffstage: false), findsNothing);
      if (kind != 'Context') {
        expect(fixture.completed, isTrue);
        expect(fixture.result, isNull);
      }
      fixture.active.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Source').hitTestable(), findsOneWidget);
      await fixture.show(tester, kind);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$kind is removed when navigation pushes another page', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await fixture.show(tester, kind);
      fixture.navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Destination')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Destination'), findsOneWidget);
      expect(find.byType(BackdropFilter, skipOffstage: false), findsNothing);
      fixture.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Source').hitTestable(), findsOneWidget);
      await fixture.show(tester, kind);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$kind is removed together with its source page', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      fixture.navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: fixture.page),
      );
      await tester.pumpAndSettle();
      final owner = ModalRoute.of(fixture.source)!;
      await fixture.show(tester, kind);
      fixture.navigator.currentState!.removeRoute(owner);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter, skipOffstage: false), findsNothing);
      expect(find.text('Source').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('context actions open dialogs in the same pane', (tester) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    await fixture.show(tester, 'Context');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byKey(_preview), findsNothing);
    expect(tester.getRect(find.byType(AppModalBackdrop)).left, 320);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(fixture.result, 'confirmed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiding a pane cancels a preview still growing on long press', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Source')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    fixture.active.value = false;
    await tester.pumpAndSettle();
    await gesture.up();
    fixture.active.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byKey(_preview), findsNothing);
    expect(find.text('Source').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _webTests() {
  for (final kind in ['Dialog', 'Sheet']) {
    testWidgets('Web $kind covers the window and returns its own result', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await fixture.show(tester, kind);
      final content = find.text('Confirm');
      expect(
        Navigator.of(tester.element(content)),
        Navigator.of(fixture.source, rootNavigator: true),
      );
      expect(
        tester.getRect(find.byType(AppModalBackdrop)),
        const Rect.fromLTWH(0, 0, 1000, 700),
      );
      expect(tester.getRect(content).center.dx, closeTo(500, 1));
      tester.view.physicalSize = const Size(760, 520);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(AppModalBackdrop)),
        const Rect.fromLTWH(0, 0, 760, 520),
      );
      await tester.tap(content);
      await tester.pumpAndSettle();
      expect(fixture.completed, isTrue);
      expect(fixture.result, 'confirmed');
      expect(fixture.navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Web $kind blocks sidebar interaction and dismisses globally', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await fixture.show(tester, kind);
      await tester.tapAt(tester.getCenter(find.text('Sidebar')));
      await tester.pumpAndSettle();
      expect(fixture.sidebarTaps, 0);
      expect(fixture.completed, isTrue);
      expect(fixture.result, isNull);
      expect(find.byType(AppModalBackdrop), findsNothing);
    });

    testWidgets('Web $kind survives pane hiding and source page removal', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      fixture.navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: fixture.page),
      );
      await tester.pumpAndSettle();
      final owner = ModalRoute.of(fixture.source)!;
      await fixture.show(tester, kind);
      fixture.active.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      fixture.navigator.currentState!.removeRoute(owner);
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      expect(fixture.completed, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.completed, isTrue);
      expect(find.byType(AppModalBackdrop), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Web context preview uses the root Navigator and full backdrop', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    await fixture.show(tester, 'Context');
    expect(
      Navigator.of(tester.element(find.byKey(_preview))),
      Navigator.of(fixture.source, rootNavigator: true),
    );
    expect(
      tester.getRect(find.byType(BackdropFilter)),
      const Rect.fromLTWH(0, 0, 1000, 700),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byKey(_preview), findsNothing);
    expect(tester.getRect(find.byType(AppModalBackdrop)).left, 0);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(fixture.result, 'confirmed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Web anchored menus extend beyond a narrow source pane', (
    tester,
  ) async {
    final fixture = _Fixture(includeMenu: true);
    await fixture.pump(tester, sidebarWidth: 800);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    final menu = find.text('A long global menu action');
    expect(tester.getRect(menu).left, lessThan(800));
    expect(
      tester.widget<MenuAnchor>(find.byType(MenuAnchor)).useRootOverlay,
      isTrue,
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(fixture.menuSelections, 1);
    expect(menu, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Web popup observation ends when an unowned popup closes', (
    tester,
  ) async {
    final observer = AppModalObserver();
    var changes = 0;
    final tracked = AppModalObserver(onChanged: () => changes++);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer, tracked],
        home: const Scaffold(body: Text('Home')),
      ),
    );
    final route = DialogRoute<void>(
      context: navigator.currentContext!,
      builder: (_) => const Text('Popup'),
    );
    navigator.currentState!.push(route);
    await tester.pumpAndSettle();
    expect(observer.hasPopups, isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.hasPopups, isFalse);
    expect(changes, 2);
  });
}
