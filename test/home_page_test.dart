import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

void main() {
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

    expect(find.text('你现在最想做什么？'), findsOneWidget);
    expect(find.text('做一个新IP'), findsOneWidget);
    expect(find.byKey(const Key('popi-message-input')), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
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
      tester.getBottomRight(find.byKey(const Key('popi-message-composer'))).dy,
      956 - 34,
    );
    final wordmarkTop =
        tester.getTopLeft(find.byKey(const Key('popi-wordmark'))).dy;

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pump();
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);
    await tester.tapAt(const Offset(10, 800));
    await tester.pump();
    expect(editableText.focusNode.hasFocus, isFalse);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.byKey(const Key('popi-message-composer'))).dy,
      956 - 300 - 20,
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -30),
    );
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
    final input = tester.widget<TextField>(
      find.byKey(const Key('popi-message-input')),
    );
    expect(input.controller?.text, '做一个新IP');

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

    final composer = tester.widget<Container>(
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
      'assets/icons/home_welcome.png',
    );

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();

    final firstTaskIcon = tester
        .widgetList<AppSvgIcon>(
          find.byType(AppSvgIcon),
        )
        .firstWhere(
          (icon) => icon.assetName == 'popi_task_red',
        );
    expect(firstTaskIcon.color, isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    final neutralTaskIcon = tester
        .widgetList<AppSvgIcon>(
          find.byType(AppSvgIcon),
        )
        .firstWhere(
          (icon) => icon.assetName == 'popi_task_neutral',
        );
    expect(neutralTaskIcon.colorMapper, isNotNull);

    final navigationLabel = tester.widget<Text>(find.text('POPi对话'));
    expect(navigationLabel.style?.color, AppTheme.dark.colorScheme.onSurface);
    expect(tester.takeException(), isNull);
  });
}
