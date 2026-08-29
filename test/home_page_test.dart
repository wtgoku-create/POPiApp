import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';

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
    expect(find.text('任务'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('popi-drawer-search'))).dy,
      53,
    );

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
}
