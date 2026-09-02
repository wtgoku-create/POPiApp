import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:extended_text_field/extended_text_field.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/home/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

void main() {
  test('message composer controller exports markdown', () async {
    final controller = PopiMessageComposerController(initialText: '初始内容');
    addTearDown(controller.dispose);

    expect(controller.markdown, '初始内容');

    await controller.setText('做一个新IP');

    expect(controller.markdown, '做一个新IP');
  });

  test('message composer controller keeps a valid selection on dismiss', () {
    final controller = PopiMessageComposerController(initialText: '输入内容');
    addTearDown(controller.dispose);
    controller.textController.selection =
        const TextSelection.collapsed(offset: 2);

    controller.dismissKeyboard();

    expect(controller.textController.selection.extentOffset, 2);
  });

  testWidgets('renders the mobile welcome layout and drawer', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.fromLTRB(24, 24, 28, 34));
    await container.read(userProvider.notifier).setUser(
          const User(
            id: '10561',
            code: 'u10561',
            name: '当前用户',
            email: 'user@popi.art',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('你现在最想做什么？'), findsOneWidget);
    expect(find.text('做一个新IP'), findsOneWidget);
    expect(find.text('跟POPi说点什么...'), findsOneWidget);
    expect(find.byKey(const Key('popi-message-input')), findsOneWidget);
    expect(find.byType(ExtendedTextField), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('popi-message-input'))).height,
      24,
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final collapsedComposerHeight = tester
        .getSize(
          find.byType(PopiMessageComposer),
        )
        .height;
    final collapsedScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('popi-home-scroll')),
    );
    expect(
      (collapsedScrollView.padding! as EdgeInsets).bottom,
      closeTo(collapsedComposerHeight + 20, .5),
    );
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
    expect(scaffold.bottomNavigationBar, isNull);
    expect(scaffold.body, isA<Stack>());
    expect(
      tester.getSize(find.byKey(const Key('popi-home-app-bar'))).height,
      56,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('popi-home-app-bar'))).dy,
      24,
    );
    expect(
      tester.getBottomRight(find.text('AI生成结果可能有误，仅供参考')).dy,
      956 - 34,
    );
    final wordmarkTop =
        tester.getTopLeft(find.byKey(const Key('popi-wordmark'))).dy;

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final animatingComposerHeight =
        tester.getSize(find.byKey(const Key('popi-message-composer'))).height;
    expect(animatingComposerHeight, greaterThan(60));
    expect(animatingComposerHeight, lessThan(112));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      112,
    );
    expect(
      tester.getSize(find.byKey(const Key('popi-message-input'))).height,
      42,
    );
    tester.testTextInput.enterText('第一行\n第二行\n第三行\n第四行\n第五行');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final growingHeight =
        tester.getSize(find.byKey(const Key('popi-message-composer'))).height;
    expect(growingHeight, greaterThan(112));
    expect(growingHeight, lessThan(154));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      154,
    );
    expect(
      tester.getSize(find.byKey(const Key('popi-message-input'))).height,
      84,
    );
    tester.testTextInput.enterText('');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final shrinkingHeight =
        tester.getSize(find.byKey(const Key('popi-message-composer'))).height;
    expect(shrinkingHeight, greaterThan(112));
    expect(shrinkingHeight, lessThan(154));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      112,
    );
    final expandedComposerHeight = tester
        .getSize(
          find.byType(PopiMessageComposer),
        )
        .height;
    final expandedScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('popi-home-scroll')),
    );
    expect(expandedComposerHeight, greaterThan(collapsedComposerHeight));
    expect(
      (expandedScrollView.padding! as EdgeInsets).bottom,
      closeTo(expandedComposerHeight + 20, .5),
    );
    final expandedComposerRect =
        tester.getRect(find.byKey(const Key('popi-message-composer')));
    await tester.tapAt(
      Offset(expandedComposerRect.center.dx, expandedComposerRect.top + 70),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      112,
    );
    expect(find.text('SDXL1.0'), findsNothing);
    expect(find.byTooltip('语音输入'), findsOneWidget);
    expect(find.text('AI生成结果可能有误，仅供参考'), findsOneWidget);
    await tester.tapAt(const Offset(10, 800));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      60,
    );
    expect(find.text('跟POPi说点什么...'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.text('AI生成结果可能有误，仅供参考')).dy,
      956 - 300 - 20,
    );
    await tester.dragFrom(const Offset(220, 300), const Offset(0, -30));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('popi-wordmark'))).dy,
      lessThan(wordmarkTop),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 1);
    await tester.pumpAndSettle();
    final composerBottomNearKeyboardClose =
        tester.getBottomRight(find.text('AI生成结果可能有误，仅供参考')).dy;
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.text('AI生成结果可能有误，仅供参考')).dy,
      composerBottomNearKeyboardClose,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('popi-wordmark'))).dy,
      wordmarkTop,
    );

    await tester.tap(find.text('做一个新IP'));
    await tester.pumpAndSettle();
    expect(find.text('做一个新IP'), findsWidgets);
    expect(
      find.byKey(const Key('popi-message-placeholder')),
      findsNothing,
    );

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();

    expect(find.text('搜索对话'), findsOneWidget);
    expect(find.text('POPi对话'), findsOneWidget);
    expect(find.text('当前用户'), findsOneWidget);
    expect(find.text('u10561'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('drawer-user-summary'))).width,
      greaterThan(81),
    );
    expect(find.text('任务'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('popi-drawer-search'))).dy,
      53,
    );
    final searchBackground = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const Key('popi-drawer-search')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final searchDecoration = searchBackground.decoration as BoxDecoration;
    expect(searchDecoration.color, AppTheme.light.colorScheme.surface);
    expect(searchDecoration.border, isA<Border>());
    expect(searchDecoration.boxShadow, isNotEmpty);
    expect(find.byTooltip('新建对话'), findsNothing);

    final navigationInkWell = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('角色'),
        matching: find.byType(InkWell),
      ),
    );
    final taskInkWell = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('生活剧情Vlog'),
        matching: find.byType(InkWell),
      ),
    );
    final pressedStates = {WidgetState.pressed};
    expect(
      navigationInkWell.overlayColor?.resolve(pressedStates),
      AppColors.brand.withValues(alpha: .12),
    );
    expect(
      taskInkWell.overlayColor?.resolve(pressedStates),
      AppColors.brand.withValues(alpha: .12),
    );
  });

  testWidgets('renders home content in English', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('What do you want to do most right now?'),
      findsOneWidget,
    );
    expect(find.text('Create a new IP'), findsOneWidget);
    expect(find.text('Say something to POPi...'), findsOneWidget);
    expect(find.byTooltip('Open navigation'), findsOneWidget);
  });

  testWidgets('collapsing the focused editor does not read dirty text layout',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 300));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }

    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      60,
    );
  });

  testWidgets('picks at most five images inside the composer and removes one',
      (tester) async {
    final imageBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final images = List.generate(
      6,
      (index) => XFile.fromData(
        imageBytes,
        path: 'picked-$index.png',
        name: 'picked-$index.png',
        mimeType: 'image/png',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: HomePage(pickImages: () async => images),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('相册'));
    await tester.pumpAndSettle();

    final imageStrip = find.byKey(const Key('popi-selected-images'));
    expect(imageStrip, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('popi-message-composer')),
        matching: imageStrip,
      ),
      findsOneWidget,
    );
    for (var index = 0; index < 5; index++) {
      expect(find.byKey(Key('popi-selected-image-$index')), findsOneWidget);
    }
    expect(find.byKey(const Key('popi-selected-image-5')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      60,
    );

    final firstImage = find.byKey(const Key('popi-selected-image-0'));
    final firstRemoveButton =
        find.byKey(const Key('popi-remove-selected-image-0'));
    expect(tester.getSize(firstImage), const Size.square(28));
    expect(firstRemoveButton, findsNothing);

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      178,
    );
    final expandedImageRect = tester.getRect(firstImage);
    final expandedRemoveButtonRect = tester.getRect(firstRemoveButton);
    expect(
      expandedImageRect.contains(expandedRemoveButtonRect.center),
      isTrue,
    );
    expect(expandedRemoveButtonRect.top, expandedImageRect.top + 3);
    expect(expandedRemoveButtonRect.right, expandedImageRect.right - 3);

    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      60,
    );
    expect(firstRemoveButton, findsNothing);

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-remove-selected-image-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('popi-selected-image-4')), findsNothing);
    expect(find.byKey(const Key('popi-selected-image-3')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('does not add the same gallery image twice', (tester) async {
    final imageBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final duplicate = XFile.fromData(
      imageBytes,
      path: 'duplicate.png',
      name: 'duplicate.png',
      mimeType: 'image/png',
    );
    final unique = XFile.fromData(
      imageBytes,
      path: 'unique.png',
      name: 'unique.png',
      mimeType: 'image/png',
    );
    var pickCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: HomePage(
            pickImages: () async =>
                pickCount++ == 0 ? [duplicate] : [duplicate, unique],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> pickFromGallery() async {
      await tester.tap(find.byTooltip('添加附件'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
    }

    await pickFromGallery();
    await pickFromGallery();

    expect(find.byKey(const Key('popi-selected-image-0')), findsOneWidget);
    expect(find.byKey(const Key('popi-selected-image-1')), findsOneWidget);
    expect(find.byKey(const Key('popi-selected-image-2')), findsNothing);
  });

  testWidgets('rejects a gallery image larger than 6MB', (tester) async {
    final oversizedImage = XFile.fromData(
      Uint8List(6 * 1024 * 1024 + 1),
      name: 'oversized.png',
      mimeType: 'image/png',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: _LocalizedTestApp(
          theme: AppTheme.light,
          home: HomePage(pickImages: () async => [oversizedImage]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('相册'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.byKey(const Key('popi-selected-images')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('uses dark theme colors on the home page and drawer',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.fromLTRB(24, 24, 28, 34));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _LocalizedTestApp(
          theme: AppTheme.dark,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final welcomePanel = tester.widget<Container>(
      find.byKey(const Key('home-welcome-panel')),
    );
    expect(
      (welcomePanel.decoration! as BoxDecoration).color,
      AppTheme.dark.colorScheme.surfaceContainerLow,
    );

    final composer = tester.widget<Container>(
      find.byKey(const Key('popi-message-composer')),
    );
    expect(
      (composer.decoration! as BoxDecoration).color,
      AppTheme.dark.colorScheme.surfaceContainerHigh,
    );
    expect(
      find.byKey(const Key('popi-composer-region-blur')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('popi-composer-region-feather')),
      findsOneWidget,
    );
    final composerRegionSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('popi-composer-region-surface')),
    );
    expect(
      composerRegionSurface.color,
      AppTheme.dark.colorScheme.surface.withValues(alpha: .14),
    );

    final mascot = tester.widget<Image>(
      find.byKey(const Key('popi-welcome-mascot')),
    );
    expect(
      (mascot.image as AssetImage).assetName,
      'assets/icons/home_welcome_banner.png',
    );

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();

    final firstTaskIcon = tester
        .widgetList<AppSvgIcon>(
          find.byType(AppSvgIcon),
        )
        .firstWhere(
          (icon) => icon.assetName == 'home_drawer_task-red',
        );
    expect(firstTaskIcon.color, isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    final neutralTaskIcon = tester
        .widgetList<AppSvgIcon>(
          find.byType(AppSvgIcon),
        )
        .firstWhere(
          (icon) => icon.assetName == 'home_drawer_task-neutral',
        );
    expect(neutralTaskIcon.colorMapper, isNotNull);

    final navigationLabel = tester.widget<Text>(find.text('POPi对话'));
    expect(navigationLabel.style?.color, AppTheme.dark.colorScheme.onSurface);
    expect(tester.takeException(), isNull);
  });
}

class _LocalizedTestApp extends StatelessWidget {
  const _LocalizedTestApp({
    required this.theme,
    required this.home,
    this.locale = const Locale('zh'),
  });

  final ThemeData theme;
  final Widget home;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );
  }
}
