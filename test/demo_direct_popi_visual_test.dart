import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

final _captureKey = GlobalKey();
final _capturesEnabled =
    Platform.environment['POPI_CREATE_SCREENSHOTS'] != null;
const _captureDirectory = 'build/direct-create-popi';

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_capturesEnabled) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_captureDirectory).create(recursive: true);
    await File(
      '$_captureDirectory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required Size size,
  required bool dark,
  required bool desktop,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final repository = DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
  addTearDown(repository.dispose);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _capturesEnabled
                ? theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'PopiCreateCapture',
                    ),
                  )
                : theme,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: DemoHomePage(repository: repository),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(Key(desktop ? 'demo-desktop-create' : 'demo-create')).first,
  );
  await tester.pumpAndSettle();
  expect(find.text('创建新的 Popi'), findsOneWidget);
  await tester.runAsync(
    () => Future.wait([
      for (final character in BotAvatarCharacter.values)
        precacheImage(
          AssetImage(character.stillAsset),
          tester.element(
            find.byKey(ValueKey('demo-assistant-avatar-${character.name}')),
          ),
        ),
    ]),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    if (!_capturesEnabled) return;
    final fontFile = File(
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    );
    if (fontFile.existsSync()) {
      final font = FontLoader('PopiCreateCapture')
        ..addFont(
          fontFile.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final testCase in [
    (name: 'mobile', size: const Size(414, 805), dark: false, desktop: false),
    (name: 'desktop', size: const Size(1200, 775), dark: false, desktop: true),
    (name: 'dark', size: const Size(375, 775), dark: true, desktop: false),
  ]) {
    testWidgets('direct Popi creation visual ${testCase.name}', (tester) async {
      if (testCase.desktop) {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      }
      try {
        await _pumpForm(
          tester,
          size: testCase.size,
          dark: testCase.dark,
          desktop: testCase.desktop,
        );
        await _capture(tester, testCase.name);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
