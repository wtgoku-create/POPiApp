import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/home/presentation/widgets/popi_message_composer.dart';
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
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('你现在最想做什么？'), findsOneWidget);
    expect(find.text('做一个新IP'), findsOneWidget);
    expect(find.byKey(const Key('popi-message-input')), findsOneWidget);
    expect(find.byType(AppFlowyEditor), findsOneWidget);
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
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      118,
    );
    expect(
      tester.getSize(find.byKey(const Key('popi-message-input'))).height,
      44,
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
    expect(find.text('SDXL1.0'), findsNothing);
    expect(find.byTooltip('语音输入'), findsOneWidget);
    expect(find.text('AI生成结果可能有误，仅供参考'), findsOneWidget);
    await tester.tapAt(const Offset(10, 800));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('popi-message-composer'))).height,
      60,
    );

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
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('popi-wordmark'))).dy,
      wordmarkTop,
    );

    await tester.tap(find.text('做一个新IP'));
    await tester.pump();
    expect(find.text('做一个新IP'), findsWidgets);

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
        child: MaterialApp(theme: AppTheme.dark, home: const HomePage()),
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

    final composer = tester.widget<AnimatedContainer>(
      find.byKey(const Key('popi-message-composer')),
    );
    expect(
      (composer.decoration! as BoxDecoration).color,
      AppTheme.dark.colorScheme.surfaceContainerHigh,
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
