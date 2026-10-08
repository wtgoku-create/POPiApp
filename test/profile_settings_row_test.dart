import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/profile/presentation/widgets/profile_settings_row.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

void main() {
  for (final width in [320.0, 440.0]) {
    for (final dark in [false, true]) {
      testWidgets('settings values align at width $width, dark: $dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const values = ['+86 156*******81', '未绑定', 'A long account nickname'];
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final (index, value) in values.indexed)
                      SettingsRow(
                        key: ValueKey('row-$index'),
                        icon: Icons.person_outline,
                        label: '账号 $index',
                        value: value,
                      ),
                    const SettingsRow(
                      key: ValueKey('row-language'),
                      icon: Icons.translate,
                      label: '语言',
                      value: '中文',
                      trailing: Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final chevrons = find.byWidgetPredicate(
          (widget) =>
              widget is AppSvgIcon &&
              widget.assetName == 'profile_settings_chevron',
        );
        expect(chevrons, findsNWidgets(values.length));
        final anchor = tester.getCenter(chevrons.first).dx;
        for (var index = 0; index < values.length; index++) {
          final row = tester.getRect(find.byKey(ValueKey('row-$index')));
          expect(tester.getCenter(chevrons.at(index)).dx, closeTo(anchor, .01));
          expect(anchor, closeTo(row.right - 26, .01));
          expect(
            tester.getRect(find.text(values[index])).right,
            closeTo(row.right - 43, .01),
          );
          expect(
            tester.getRect(find.text('账号 $index')).right,
            lessThanOrEqualTo(tester.getRect(find.text(values[index])).left),
          );
        }
        expect(
          tester.getCenter(find.byIcon(Icons.expand_more)).dx,
          closeTo(anchor, .01),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
