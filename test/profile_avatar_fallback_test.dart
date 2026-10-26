import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/profile/presentation/widgets/profile_chrome.dart';

void main() {
  testWidgets('corrupt restored local avatar falls back to the default image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(
            imageProvider: MemoryImage(Uint8List.fromList([1, 2, 3])),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/icons/common_user_avatar.png',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
