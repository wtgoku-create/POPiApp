import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

final _captureKey = GlobalKey();
final _capturesEnabled =
    Platform.environment['POPI_CREATIVE_MEMORY_SCREENSHOTS'] != null;
const _captureDirectory = 'build/creative-memory';

void main() {
  setUpAll(() async {
    if (!_capturesEnabled) return;
    final fontFile = File('/System/Library/Fonts/Hiragino Sans GB.ttc');
    if (fontFile.existsSync()) {
      await (FontLoader(
        'CreativeMemoryCapture',
      )..addFont(fontFile.readAsBytes().then(ByteData.sublistView))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('creative memory page and editor remain visually readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());
    final repository = DemoRepository(storage)..restore();
    addTearDown(repository.dispose);
    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(
        creativeMemory: const DemoCreativeMemory(
          text:
              '画面保持暖色、自然光和生活纪录感，保留真实环境与日常细节。图片默认使用 Image2.5 Flare官方，比例为 3:4；视频默认使用 Seedance2.5，比例为 9:16。',
        ),
      ),
    );
    final theme = AppTheme.light;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: ToastificationWrapper(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _capturesEnabled
                ? theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'CreativeMemoryCapture',
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
            home: DemoSettingsPage(
              repository: repository,
              sessionId: 'inspiration',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('demo-creative-memory-card'));
    final infoScrollable = find
        .descendant(
          of: find.byKey(const PageStorageKey('demo-settings-info')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(card, 180, scrollable: infoScrollable);
    await tester.drag(infoScrollable, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    await _capture(tester, 'page');

    await tester.tap(find.byKey(const Key('demo-creative-memory-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-creative-memory-input')), findsOneWidget);
    await _capture(tester, 'edit-sheet');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_capturesEnabled) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$_captureDirectory/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
