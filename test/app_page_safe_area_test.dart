import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/shared/widgets/app_page_safe_area.dart';

void main() {
  testWidgets('page gutters include consumed side insets exactly once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPageSafeArea(
            top: false,
            bottom: false,
            child: Builder(
              builder: (context) => Padding(
                padding: AppPageSafeArea.horizontalPaddingOf(context),
                child: const SizedBox.expand(key: Key('page-content')),
              ),
            ),
          ),
        ),
      ),
    );
    for (final (left, right) in [
      (0.0, 0.0),
      (12.0, 12.0),
      (62.0, 0.0),
      (0.0, 62.0),
      (0.0, 0.0),
    ]) {
      tester.view.padding = FakeViewPadding(
        left: left,
        right: right,
        bottom: 34,
      );
      await tester.pump();
      final content = tester.getRect(find.byKey(const Key('page-content')));
      expect(content.left, left < 20 ? 20 : left);
      expect(content.right, 900 - (right < 20 ? 20 : right));
      expect(content.bottom, 640);
    }
    expect(tester.takeException(), isNull);
  });
}
