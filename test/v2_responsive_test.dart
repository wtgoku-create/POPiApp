import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/session_artifacts_sheet.dart';
import 'package:popi_ai_app/features/v2_assets/presentation/v2_assets_page.dart';
import 'package:popi_ai_app/features/v2_home/presentation/v2_home_page.dart';
import 'package:popi_ai_app/features/v2_session/presentation/v2_chat_page.dart';
import 'package:popi_ai_app/features/v2_session/presentation/v2_settings_page.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_repository.dart';
import 'package:popi_ai_app/features/v2_shared/domain/v2_models.dart';
import 'package:popi_ai_app/features/v2_shared/presentation/widgets/v2_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

const _captureKey = Key('v2-responsive-capture');

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Future<V2Repository> _pump(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({});
  final repository = V2Repository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  );
  addTearDown(repository.dispose);
  var theme = dark ? AppTheme.dark : AppTheme.light;
  final fontPath = Platform.environment['V2_PREVIEW_FONT'];
  if (fontPath != null) {
    await tester.runAsync(() async {
      final bytes = await File(fontPath).readAsBytes();
      final loader = FontLoader('V2Preview')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'V2Preview'),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: theme,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RepaintBoundary(
            key: _captureKey,
            child: V2HomePage(repository: repository),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['V2_PREVIEW_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final images = tester.widgetList<Image>(find.byType(Image));
    final context = tester.element(find.byKey(_captureKey));
    await Future.wait(
      images.map((image) => precacheImage(image.image, context)),
    );
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('sidebar gutters include landscape safe areas only once', (
    tester,
  ) async {
    await _pump(tester, size: const Size(900, 390));
    addTearDown(tester.view.resetPadding);
    for (final (inset, expectedLeft) in [
      (0.0, 20.0),
      (24.0, 24.0),
      (62.0, 62.0),
    ]) {
      tester.view.padding = FakeViewPadding(left: inset, right: 62);
      await tester.pumpAndSettle();
      final search = tester.getRect(find.byType(V2Search).hitTestable());
      expect(search.left, expectedLeft);
      expect(search.right, 320 - 20);
      expect(tester.getRect(find.byTooltip('个人资料')).left, expectedLeft);
      expect(
        tester.getRect(find.byKey(const Key('demo-create'))).right,
        320 - 20,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('chat state and attachments survive folding and unfolding', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('尚未选择会话'), findsOneWidget);
    await tester.tap(find.text('爱丽丝视频'));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(V2ChatPage));
    final composer = find.byType(PopiMessageComposer);
    await tester
        .widget<PopiMessageComposer>(composer)
        .controller
        .setText('让她在街角发现一家新的花店');
    tester.widget<PopiMessageComposer>(composer).onAttachment();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(V2AssetCard).hitTestable().first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PopiMessageComposer>(composer).selectedAssets,
      hasLength(1),
    );
    await _capture(tester, 'expanded-chat');

    for (final size in [
      const Size(390, 844),
      const Size(900, 700),
      const Size(1200, 800),
      const Size(390, 844),
    ]) {
      await _resize(tester, size);
      expect(tester.state(find.byType(V2ChatPage)), same(state));
      final current = tester.widget<PopiMessageComposer>(composer);
      expect(current.controller.markdown, '让她在街角发现一家新的花店');
      expect(current.selectedAssets, hasLength(1));
      expect(
        find.text('爱丽丝视频').hitTestable(),
        size.width < 840 ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await _capture(tester, 'compact-chat');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('爱丽丝视频').hitTestable(), findsOneWidget);
    expect(find.byType(V2ChatPage), findsNothing);
  });

  testWidgets('assets switch the right pane and preserve chat and filters', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('爱丽丝视频'));
    await tester.pumpAndSettle();
    final chatState = tester.state(find.byType(V2ChatPage));
    await tester
        .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
        .controller
        .setText('保留这条草稿');
    final sidebar = tester.getRect(find.byKey(const Key('v2-library-pane')));
    final tabs = tester.getRect(find.byKey(const Key('demo-bottom-tabs')));
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('v2-library-pane'))), sidebar);
    expect(tester.getRect(find.byKey(const Key('demo-bottom-tabs'))), tabs);
    expect(find.text('爱丽丝视频').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byType(V2AssetsView)).left, 320);
    expect(tester.getRect(find.byType(V2AssetsView)).width, 880);
    final assetsState = tester.state(find.byType(V2AssetsView));
    await tester.tap(find.text('奶茶店的午后').hitTestable());
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SessionArtifactDetailPage)).left, 320);
    expect(find.text('爱丽丝视频').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SessionArtifactDetailPage), findsNothing);
    final grid = find.byType(SliverGrid);
    int columns() =>
        (tester.widget<SliverGrid>(grid).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;
    expect(columns(), 4);
    await tester.tap(find.text('图片').hitTestable());
    await tester.pumpAndSettle();
    await _capture(tester, 'expanded-gallery');
    await _resize(tester, const Size(390, 844));
    expect(tester.state(find.byType(V2AssetsView)), same(assetsState));
    expect(find.text('爱丽丝视频').hitTestable(), findsNothing);
    expect(tester.getRect(find.byType(V2AssetsView)).left, 0);
    expect(columns(), 2);
    expect(find.text('周末出游成片'), findsNothing);
    await _resize(tester, const Size(1200, 800));
    expect(columns(), 4);
    expect(find.text('周末出游成片'), findsNothing);
    await _resize(tester, const Size(1600, 900));
    expect(columns(), 5);
    await tester.tap(find.byKey(const Key('demo-tab-0')));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(V2ChatPage)), same(chatState));
    expect(
      tester
          .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
          .controller
          .markdown,
      '保留这条草稿',
    );
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(V2AssetsView)), same(assetsState));
    expect(find.text('周末出游成片'), findsNothing);
    await tester.tap(find.text('灵感到成片').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(V2ChatPage), findsOneWidget);
    expect(find.byType(V2AssetsView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings and nested back navigation survive resizing', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 844));
    await tester.tap(find.text('灵感到成片'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('能力').hitTestable());
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(V2SettingsPage));
    await _resize(tester, const Size(1200, 800));
    expect(tester.state(find.byType(V2SettingsPage)), same(state));
    expect(find.text('添加成员').hitTestable(), findsOneWidget);
    await _capture(tester, 'expanded-settings');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(V2ChatPage), findsOneWidget);
    await _resize(tester, const Size(390, 844));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(V2ChatPage), findsNothing);
    expect(find.text('灵感到成片').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark narrow detail remains usable with an open keyboard', (
    tester,
  ) async {
    await _pump(tester, size: const Size(900, 640), dark: true);
    await tester.tap(find.text('爱丽丝视频'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final composer = tester.getRect(find.byType(PopiMessageComposer));
    expect(composer.bottom, lessThanOrEqualTo(640 - 260));
    expect(composer.left, greaterThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty states scroll in short windows with the keyboard open', (
    tester,
  ) async {
    final repository = await _pump(tester, size: const Size(900, 240));
    expect(tester.takeException(), isNull);
    await repository.createSession('空会话', V2SessionKind.conversation);
    await tester.pumpAndSettle();
    await tester.tap(find.text('空会话'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _resize(tester, const Size(390, 480));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(PopiMessageComposer)).bottom,
      lessThanOrEqualTo(240),
    );
    expect(tester.takeException(), isNull);
  });
}
