import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_icon_button_glass.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required ThemeData theme,
    double size = 40,
    VoidCallback? onPressed,
    FocusNode? focusNode,
    ButtonStyle? style,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: size,
              child: IconButton(
                key: const Key('button'),
                focusNode: focusNode,
                style: style,
                tooltip: 'Options',
                padding: EdgeInsets.zero,
                onPressed: onPressed,
                icon: AppSvgIcon.asset(
                  'home_drawer_more',
                  key: const Key('icon'),
                  size: 30,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Material buttonSurface(WidgetTester tester) => tester.widget<Material>(
    find
        .ancestor(
          of: find.byKey(const Key('icon')),
          matching: find.byType(Material),
        )
        .first,
  );

  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.dark : AppTheme.light;
    for (final size in [30.0, 40.0]) {
      testWidgets('hover shows a stable $size hot area in dark mode: $dark', (
        tester,
      ) async {
        var clicks = 0;
        await pumpButton(
          tester,
          theme: theme,
          size: size,
          onPressed: () => clicks++,
        );
        final button = find.byKey(const Key('button'));
        final initialRect = tester.getRect(button);
        final initialColor = buttonSurface(tester).color;
        expect(find.byType(AppIconButtonGlass), findsOneWidget);
        expect(tester.getSize(find.byType(BackdropFilter)), Size.square(size));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(10, 10));
        // Hover beside the SVG dots, within the button's full clickable area.
        await mouse.moveTo(initialRect.centerLeft + const Offset(4, 0));
        await tester.pumpAndSettle();
        expect(buttonSurface(tester).color, isNot(initialColor));
        expect(buttonSurface(tester).shape, isA<CircleBorder>());
        expect(tester.getRect(button), initialRect);
        expect(clicks, 0);

        await mouse.moveTo(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(buttonSurface(tester).color, initialColor);
        await tester.tapAt(initialRect.centerLeft + const Offset(4, 0));
        await tester.pumpAndSettle();
        expect(clicks, 1);
        expect(tester.getRect(button), initialRect);
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('disabled icon buttons have no hover hot area: $dark', (
      tester,
    ) async {
      await pumpButton(tester, theme: theme);
      final button = find.byKey(const Key('button'));
      final initialRect = tester.getRect(button);
      final initialColor = buttonSurface(tester).color;
      expect(find.byType(AppIconButtonGlass), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(initialRect.center);
      await tester.pumpAndSettle();
      expect(buttonSurface(tester).color, initialColor);
      expect(tester.getRect(button), initialRect);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('glass stays 40px within a larger button tap target', (
    tester,
  ) async {
    var clicks = 0;
    await pumpButton(
      tester,
      theme: AppTheme.light,
      size: 56,
      onPressed: () => clicks++,
    );
    final button = tester.getRect(find.byKey(const Key('button')));
    final glass = tester.getRect(find.byType(BackdropFilter));
    expect(button.size, const Size.square(56));
    expect(glass.size, const Size.square(40));
    expect(glass.center, button.center);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(BackdropFilter),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, Colors.white.withValues(alpha: .5));
    expect(decoration.border, Border.all(color: Colors.white));
    await tester.tapAt(button.centerLeft + const Offset(4, 0));
    await tester.pumpAndSettle();
    expect(clicks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filled and non-circular buttons retain their own surfaces', (
    tester,
  ) async {
    for (final style in [
      IconButton.styleFrom(backgroundColor: AppColors.brand),
      IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ]) {
      await pumpButton(
        tester,
        theme: AppTheme.light,
        onPressed: () {},
        style: style,
      );
      expect(find.byType(AppIconButtonGlass), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('keyboard focus has visible feedback and can activate', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var clicks = 0;
    await pumpButton(
      tester,
      theme: AppTheme.light,
      focusNode: focusNode,
      onPressed: () => clicks++,
    );
    final initialColor = buttonSurface(tester).color;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    expect(buttonSurface(tester).color, isNot(initialColor));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(clicks, 1);
    expect(tester.takeException(), isNull);
  });
}
