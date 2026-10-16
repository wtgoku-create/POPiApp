import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_account_icon.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

void main() {
  for (final asset in ['ip_guide_account', 'project_default_avatar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'account icon uses exact server color for $asset dark=$dark',
        (tester) async {
          final color = ValueNotifier<String?>('#FEF2ED');
          addTearDown(color.dispose);
          const boundaryKey = Key('account-icon-pixels');
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: ValueListenableBuilder<String?>(
                      valueListenable: color,
                      builder: (_, value, _) => AppAccountIcon(
                        assetName: asset,
                        backgroundColor: value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final (hex, expected) in [
            ('#FEF2ED', const Color(0xFFFEF2ED)),
            ('#edf5fe', const Color(0xFFEDF5FE)),
          ]) {
            color.value = hex;
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byType(AppAccountIcon)),
              const Size(50, 50),
            );
            final actual = await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(boundaryKey),
              );
              final image = await boundary.toImage();
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final offset = (25 * image.width + 3) * 4;
              final pixel = Color.fromARGB(
                data.getUint8(offset + 3),
                data.getUint8(offset),
                data.getUint8(offset + 1),
                data.getUint8(offset + 2),
              );
              image.dispose();
              return pixel;
            });
            expect(actual, expected);
            final icon = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
            expect(icon.assetName, asset);
            expect(
              icon.colorMapper!.substitute(null, 'path', 'fill', Colors.white),
              Colors.white,
            );
          }
          for (final invalid in [null, '', '#FFF', '#GGGGGG', 'red']) {
            color.value = invalid;
            await tester.pumpAndSettle();
            expect(
              tester.widget<AppSvgIcon>(find.byType(AppSvgIcon)).colorMapper,
              isNull,
            );
            expect(
              tester.getSize(find.byType(AppAccountIcon)),
              const Size(50, 50),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
