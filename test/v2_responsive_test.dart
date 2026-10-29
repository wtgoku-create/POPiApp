import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/profile/presentation/points_details_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/session_artifacts_sheet.dart';
import 'package:popi_ai_app/features/v2_assets/presentation/v2_assets_page.dart';
import 'package:popi_ai_app/features/v2_home/presentation/v2_home_page.dart';
import 'package:popi_ai_app/features/v2_home/presentation/widgets/v2_create_popi_sheet.dart';
import 'package:popi_ai_app/features/v2_session/presentation/v2_chat_page.dart';
import 'package:popi_ai_app/features/v2_session/presentation/v2_settings_page.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_repository.dart';
import 'package:popi_ai_app/features/v2_shared/domain/v2_models.dart';
import 'package:popi_ai_app/features/v2_shared/presentation/widgets/v2_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_glass_app_bar.dart';
import 'package:popi_ai_app/shared/widgets/app_dialog.dart';
import 'package:popi_ai_app/shared/widgets/app_menu.dart';
import 'package:popi_ai_app/shared/widgets/app_modal_backdrop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

const _captureKey = Key('v2-responsive-capture');
const _windowCaptureKey = Key('v2-window-capture');

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Future<V2Repository> _pump(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
  bool dark = false,
  Widget? routedContent,
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
        child: RepaintBoundary(
          key: _windowCaptureKey,
          child: MaterialApp(
            theme: theme,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: RepaintBoundary(
              key: _captureKey,
              child: V2HomePage(
                repository: repository,
                routedContent: routedContent,
                routeActive: routedContent != null,
              ),
            ),
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
    find.byKey(_windowCaptureKey),
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
  for (final dark in [false, true]) {
    testWidgets('composer visibly blurs messages beneath it: dark=$dark', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(right: 62);
      addTearDown(tester.view.resetPadding);
      await _pump(tester, size: const Size(950, 640), dark: dark);
      await tester.tap(find.text('爱丽丝视频'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(V2ChatPage));
        await Future.wait(
          tester
              .widgetList<Image>(find.byType(Image))
              .map((image) => precacheImage(image.image, context)),
        );
      });
      await tester.pumpAndSettle();
      final composer = tester.getRect(find.byType(PopiMessageComposer));
      final list = find.byType(ChatAnimatedList);
      expect(tester.getRect(list).bottom, composer.bottom);
      expect(
        tester.widget<ChatAnimatedList>(list).bottomPadding,
        composer.height + 10,
      );
      final filter = tester.renderObject<RenderBackdropFilter>(
        find.descendant(
          of: find.byKey(const Key('v2-chat-composer-backdrop')),
          matching: find.byType(BackdropFilter),
        ),
      );
      Future<List<int>> bandPixels() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_captureKey),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final bytes = data!.buffer.asUint8List();
            return [
              for (
                var y = composer.top.toInt() - 8;
                y < composer.top.toInt() + 8;
                y++
              )
                ...bytes.sublist(
                  (y * image.width + 400) * 4,
                  (y * image.width + 580) * 4,
                ),
            ];
          } finally {
            image.dispose();
          }
        }))!;
      }

      final blurred = await bandPixels();
      filter.enabled = false;
      await tester.pump();
      final sharp = await bandPixels();
      final difference =
          List.generate(
            blurred.length,
            (i) => (blurred[i] - sharp[i]).abs(),
          ).fold<int>(0, (sum, value) => sum + value) /
          blurred.length;
      expect(difference, greaterThan(1));
      filter.enabled = true;
      await tester.pump();
      await _capture(
        tester,
        'composer-visible-blur-${dark ? 'dark' : 'light'}',
      );
      final scrollButton = find.byKey(const Key('v2-chat-scroll-to-bottom'));
      expect(tester.getRect(scrollButton).bottom, lessThan(composer.top));
      await tester.tap(scrollButton);
      await tester.pumpAndSettle();
      final lastAsset = find.byWidgetPredicate(
        (widget) => widget is V2AssetCard && widget.asset.id == 'milk',
      );
      expect(tester.getRect(lastAsset).bottom, lessThanOrEqualTo(composer.top));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'edit member footer stays compact and clears the home indicator',
    (tester) async {
      tester.view.padding = const FakeViewPadding(right: 62, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      await _pump(tester, size: const Size(950, 640));
      await tester.tap(find.text('爱丽丝视频'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('能力').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('POPi').last);
      await tester.pumpAndSettle();
      final body = find.byType(V2SheetBody);
      final button = find.descendant(
        of: body,
        matching: find.byType(V2PrimaryButton),
      );
      expect(find.text('编辑成员'), findsOneWidget);
      expect(tester.getRect(body).bottom - tester.getRect(button).bottom, 12);
      await tester.scrollUntilVisible(
        find.text('背景颜色'),
        250,
        scrollable: find
            .descendant(
              of: find.descendant(
                of: body,
                matching: find.byType(CustomScrollView),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'edit-member-footer-landscape');

      tester.view.padding = const FakeViewPadding(bottom: 34);
      await _resize(tester, const Size(390, 844));
      expect(tester.getRect(body).bottom - tester.getRect(button).bottom, 34);

      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(body).bottom, 544);
      expect(tester.getRect(body).bottom - tester.getRect(button).bottom, 12);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(body, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('member sheet stays narrow and centered inside the detail pane', (
    tester,
  ) async {
    await _pump(tester, size: const Size(980, 650));
    await tester.tap(find.text('爱丽丝视频'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('能力').hitTestable());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加成员').hitTestable());
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final surface = find
        .descendant(of: sheet, matching: find.byType(Material))
        .first;
    final state = tester.state(sheet);
    for (final size in [
      const Size(980, 650),
      const Size(900, 390),
      const Size(1200, 800),
      const Size(390, 844),
    ]) {
      await _resize(tester, size);
      final pane = tester.getRect(find.byKey(const Key('v2-detail-pane')));
      final rect = tester.getRect(surface);
      expect(rect.width, size.width < 840 ? 390 : 480);
      expect(rect.center.dx, pane.center.dx);
      expect(tester.state(sheet), same(state));
      expect(find.text('确认').hitTestable(), findsOneWidget);
      await _capture(tester, 'member-sheet-${size.width.toInt()}');
      expect(tester.takeException(), isNull);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.byType(V2SettingsPage), findsOneWidget);
  });

  testWidgets(
    'pane dialogs and sheets leave sidebar pixels and chat state intact',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.text('爱丽丝视频'));
      await tester.pumpAndSettle();
      final chat = tester.state(find.byType(V2ChatPage));
      await tester.runAsync(() async {
        final context = tester.element(find.byKey(_captureKey));
        await Future.wait(
          tester
              .widgetList<Image>(find.byType(Image))
              .map((image) => precacheImage(image.image, context)),
        );
      });
      await tester.pumpAndSettle();

      Future<List<int>> sidebarPixels() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_captureKey),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final bytes = data!.buffer.asUint8List();
            return [
              for (var row = 0; row < image.height; row++)
                ...bytes.sublist(
                  row * image.width * 4,
                  (row * image.width + 320) * 4,
                ),
            ];
          } finally {
            image.dispose();
          }
        }))!;
      }

      final before = await sidebarPixels();
      AppDialog.confirm(
        context: tester.element(find.byType(V2ChatPage)),
        title: 'Remove attachment?',
        description: 'This attachment will be removed.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Remove',
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(AppModalBackdrop)).left, 320);
      expect(listEquals(before, await sidebarPixels()), isTrue);
      await _capture(tester, 'expanded-pane-dialog');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(V2ChatPage)), same(chat));

      tester
          .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
          .onAttachment();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(AppModalBackdrop)).left, 320);
      expect(listEquals(before, await sidebarPixels()), isTrue);
      await _capture(tester, 'expanded-pane-sheet');
      await _resize(tester, const Size(390, 844));
      expect(tester.getRect(find.byType(AppModalBackdrop)).left, 0);
      await _capture(tester, 'compact-pane-sheet');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(V2ChatPage)), same(chat));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sidebar menus stay local and rename and delete dialogs are global',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.text('爱丽丝视频'));
      await tester.pumpAndSettle();
      final chat = tester.state(find.byType(V2ChatPage));
      await tester.longPress(find.text('爱丽丝视频').hitTestable().first);
      await tester.pumpAndSettle();
      final panel = find.byKey(const Key('app-context-menu-panel'));
      expect(tester.getRect(panel).right, lessThanOrEqualTo(320));
      await _capture(tester, 'expanded-sidebar-context');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(tester.state(find.byType(V2ChatPage)), same(chat));

      await tester.longPress(find.text('爱丽丝视频').hitTestable().first);
      await tester.pumpAndSettle();
      final menuContext = tester.element(
        find.byWidgetPredicate(
          (widget) => widget is AppContextMenu && widget.label == '爱丽丝视频',
        ),
      );
      final l = AppLocalizations.of(menuContext)!;
      await tester.tap(find.text(l.renameProjectItem));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(AppModalBackdrop)),
        const Rect.fromLTWH(0, 0, 1200, 800),
      );
      expect(tester.getRect(find.byType(AppDialog)).center.dx, 600);
      await _capture(tester, 'expanded-global-rename');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.state(find.byType(V2ChatPage)), same(chat));
      await tester.longPress(find.text('爱丽丝视频').hitTestable().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.delete));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(AppModalBackdrop)),
        const Rect.fromLTWH(0, 0, 1200, 800),
      );
      expect(tester.getRect(find.byType(AppDialog)).center.dx, 600);
      await _capture(tester, 'expanded-global-delete');
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(V2ChatPage)), same(chat));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching panes dismisses sheets and upload uses the assets navigator',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.text('爱丽丝视频'));
      await tester.pumpAndSettle();
      final chat = tester.state(find.byType(V2ChatPage));
      tester
          .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
          .onAttachment();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pumpAndSettle();
      expect(find.byType(AppModalBackdrop, skipOffstage: false), findsNothing);
      await tester.tap(find.byKey(const Key('demo-upload')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(AppModalBackdrop)).left, 320);
      await tester.tap(find.byKey(const Key('demo-tab-0')));
      await tester.pumpAndSettle();
      expect(find.byType(AppModalBackdrop, skipOffstage: false), findsNothing);
      expect(tester.state(find.byType(V2ChatPage)), same(chat));
      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pumpAndSettle();
      expect(find.byType(AppModalBackdrop), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat footer has no gap beside the side system bar', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(right: 62, bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await _pump(tester, size: const Size(950, 640));
    await tester.tap(find.text('爱丽丝视频'));
    await tester.pumpAndSettle();
    final composer = find.byType(PopiMessageComposer);
    final backdrop = find.byKey(const Key('v2-chat-composer-backdrop'));
    final disclaimer = find.text('AI生成结果可能有误，仅供参考');
    expect(tester.getRect(composer).bottom, 640);
    expect(tester.getRect(disclaimer).bottom, closeTo(640, .01));
    expect(
      tester.getRect(backdrop),
      tester
          .getRect(composer)
          .expandToInclude(tester.getRect(composer).translate(0, -16)),
    );
    await _capture(tester, 'chat-footer-no-bottom-gap');

    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    await _resize(tester, const Size(390, 844));
    expect(tester.getRect(composer).bottom, 844 - 34);
    expect(tester.getRect(backdrop).bottom, 844 - 34);

    tester.view.padding = const FakeViewPadding(top: 62);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.getRect(composer).bottom, 844 - 260);
    expect(tester.getRect(backdrop).bottom, 844 - 260);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings tabs reach the bottom without a fixed safe area strip',
    (tester) async {
      tester.view.padding = const FakeViewPadding(right: 62, bottom: 34);
      addTearDown(tester.view.resetPadding);
      await _pump(tester, size: const Size(950, 640));
      await tester.tap(find.text('爱丽丝视频'));
      await tester.pumpAndSettle();
      final composer = tester.getRect(find.byType(PopiMessageComposer));
      expect(composer.bottom, 640);
      await tester.tap(find.byKey(const Key('demo-settings')));
      await tester.pumpAndSettle();

      for (final (label, name) in [
        ('信息', 'info'),
        ('能力', 'skills'),
        ('产物', 'assets'),
      ]) {
        await tester.tap(find.text(label).hitTestable());
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(NestedScrollView)).bottom, 640);
        expect(tester.getRect(find.byType(TabBarView)).bottom, 640);
        final tabs = tester.getRect(
          find.byType(V2Segments).hitTestable().first,
        );
        expect(tabs.left, 320 + 20);
        expect(tabs.right, 950 - 62);
        final scroll = find.descendant(
          of: find.byType(TabBarView),
          matching: find.bySubtype<ScrollView>().hitTestable(),
        );
        expect(tester.getRect(scroll.first).bottom, 640);
        expect(tester.getRect(scroll.first).right, 950 - 62);
        await _capture(tester, 'settings-bottom-$name');
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(PopiMessageComposer)), composer);
      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(V2AssetsView)).bottom, 640);
      final search = find.descendant(
        of: find.byType(V2AssetsView),
        matching: find.byType(V2Search),
      );
      expect(tester.getRect(search).left, 320 + 20);
      expect(tester.getRect(search).right, 950 - 62);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detail header blur leaves sidebar pixels unchanged', (
    tester,
  ) async {
    final showHeader = ValueNotifier(false);
    addTearDown(showHeader.dispose);
    await _pump(
      tester,
      routedContent: ValueListenableBuilder<bool>(
        valueListenable: showHeader,
        builder: (context, visible, _) => Scaffold(
          extendBodyBehindAppBar: true,
          appBar: visible
              ? AppGlassAppBar(child: AppBar(title: const Text('Chat')))
              : null,
          body: ListView.builder(
            padding: EdgeInsets.zero,
            itemExtent: 12,
            itemCount: 100,
            itemBuilder: (_, index) =>
                ColoredBox(color: index.isEven ? Colors.black : Colors.white),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      final context = tester.element(find.byKey(_captureKey));
      await Future.wait(
        tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => precacheImage(image.image, context)),
      );
    });
    await tester.pumpAndSettle();

    Future<List<int>> sidebarPixels() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_captureKey),
      );
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final bytes = data!.buffer.asUint8List();
          return <int>[
            for (var row = 0; row < image.height; row++)
              ...bytes.sublist(
                row * image.width * 4,
                (row * image.width + 320) * 4,
              ),
          ];
        } finally {
          image.dispose();
        }
      }))!;
    }

    await _capture(tester, 'sidebar-before-detail-glass');
    final before = await sidebarPixels();
    showHeader.value = true;
    await tester.pumpAndSettle();
    await _capture(tester, 'sidebar-after-detail-glass');
    final after = await sidebarPixels();
    expect(listEquals(before, after), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('points content clears the system bar without a sidebar inset', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(right: 62, bottom: 21);
    addTearDown(tester.view.resetPadding);
    await _pump(
      tester,
      size: const Size(950, 680),
      routedContent: const PointsDetailsPage(
        refreshOnOpen: false,
        loadPointsLogOnOpen: false,
      ),
    );
    final card = tester.getRect(find.byKey(const Key('points-summary-card')));
    expect(card.left, 320 + 20);
    expect(card.right, 950 - 62);
    expect(tester.getRect(find.byType(V2Search).hitTestable()).right, 320 - 20);
    await _capture(tester, 'expanded-points-safe-area');
    expect(tester.takeException(), isNull);
  });

  testWidgets('create sheet stays in its originating pane', (tester) async {
    tester.view.padding = const FakeViewPadding(right: 62, bottom: 21);
    addTearDown(tester.view.resetPadding);
    await _pump(tester, size: const Size(900, 700));
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final content = find.descendant(
      of: find.byType(V2CreatePopiSheet),
      matching: find.byType(CustomScrollView),
    );
    expect(tester.getRect(content).left, 20);
    expect(tester.getRect(content).right, 320 - 20);
    await _capture(tester, 'create-popi-sidebar');
    await tester.tap(find.byKey(const Key('v2-create-popi-confirm')));
    await tester.pumpAndSettle();
    final chat = find.byType(V2ChatPage);
    expect(tester.getRect(chat).left, 320);
    expect(tester.getRect(chat).right, 900);
    expect(
      tester.getRect(find.byKey(const Key('v2-role-onboarding'))).right,
      lessThanOrEqualTo(900 - 62),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('create sheet and empty chat match the mobile design', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 52, bottom: 34);
    addTearDown(tester.view.resetPadding);
    await _pump(tester, size: const Size(440, 956));
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await _capture(tester, 'create-popi-mobile');
    expect(
      tester.getSize(find.byKey(const Key('v2-create-popi-preview'))),
      const Size.square(100),
    );
    await tester.tap(find.byKey(const Key('v2-create-popi-name')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('v2-create-popi-confirm'))).bottom,
      lessThanOrEqualTo(956 - 300),
    );
    await _capture(tester, 'create-popi-keyboard');
    tester.view.viewInsets = const FakeViewPadding();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-create-popi-confirm')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('v2-role-onboarding'))),
      const Size(400, 230),
    );
    await _capture(tester, 'empty-chat-mobile');
    await _resize(tester, const Size(320, 680));
    await _capture(tester, 'empty-chat-small');
    await tester.ensureVisible(find.byKey(const Key('v2-create-diy-role')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('v2-create-diy-role'))).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(PopiMessageComposer)).top),
    );
    expect(tester.takeException(), isNull);
  });

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
