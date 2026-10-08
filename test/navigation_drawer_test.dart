import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';

import 'support/project_fixtures.dart';

void main() {
  Future<void> pumpDrawer(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    ThemeData? theme,
    Locale locale = const Locale('zh'),
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(FixtureProjectRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: '当前用户', email: ''));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: const SessionPage(initialPrompt: '旧草稿'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
  }

  testWidgets('project transition animates and reverses smoothly', (
    tester,
  ) async {
    await pumpDrawer(tester);
    final project = find.byKey(const Key('drawer-project-0'));
    final conversations = find.byKey(
      const Key('drawer-project-conversations-0'),
    );
    final footer = find.byKey(const Key('drawer-profile-button'));
    final footerRect = tester.getRect(footer);
    final fullHeight = tester.getSize(conversations).height;
    final nextProject = find.byKey(const Key('drawer-project-1'));
    final initialNextTop = tester.getTopLeft(nextProject).dy;
    final chevron = find.descendant(
      of: project,
      matching: find.byType(RotationTransition),
    );

    await tester.tap(project);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final intermediateHeight = tester.getSize(conversations).height;
    expect(intermediateHeight, greaterThan(0));
    expect(intermediateHeight, lessThan(fullHeight));
    final nextTop = tester.getTopLeft(nextProject).dy;
    expect(nextTop, greaterThan(initialNextTop - fullHeight));
    expect(nextTop, lessThan(initialNextTop));
    final turns = tester.widget<RotationTransition>(chevron).turns.value;
    expect(turns, greaterThan(0));
    expect(turns, lessThan(.25));
    expect(
      find.byKey(const Key('drawer-conversation-0-0')).hitTestable(),
      findsNothing,
    );
    expect(tester.getRect(footer), footerRect);

    await tester.tap(project);
    await tester.pump();
    expect(
      tester.getSize(conversations).height,
      closeTo(intermediateHeight, .01),
    );
    await tester.pump(const Duration(milliseconds: 110));
    expect(
      tester.getSize(conversations).height,
      greaterThan(intermediateHeight),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(conversations).height, fullHeight);
    expect(tester.widget<RotationTransition>(chevron).turns.value, .25);

    await tester.tap(project);
    await tester.pumpAndSettle();
    expect(tester.getSize(conversations).height, 0);
    expect(find.byKey(const Key('drawer-conversation-0-0')), findsNothing);
    expect(tester.getRect(footer), footerRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project transition respects reduced motion', (tester) async {
    await pumpDrawer(tester, disableAnimations: true);
    final project = find.byKey(const Key('drawer-project-0'));
    final conversations = find.byKey(
      const Key('drawer-project-conversations-0'),
    );
    final fullHeight = tester.getSize(conversations).height;
    await tester.tap(project);
    await tester.pump();
    expect(tester.getSize(conversations).height, 0);
    await tester.tap(project);
    await tester.pump();
    expect(tester.getSize(conversations).height, fullHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the footer fixed while project groups change', (
    tester,
  ) async {
    await pumpDrawer(tester);
    final footer = find.byKey(const Key('drawer-profile-button'));
    final footerRect = tester.getRect(footer);
    expect(find.byKey(const Key('drawer-conversation-0-1')), findsOneWidget);
    expect(find.byKey(const Key('drawer-conversation-1-3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('drawer-project-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-conversation-0-1')), findsNothing);
    expect(tester.getRect(footer), footerRect);
    await tester.tap(find.byKey(const Key('drawer-project-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-conversation-0-1')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('drawer-project-0'))).height,
      42,
    );
    expect(
      tester.getSize(find.byKey(const Key('drawer-conversation-0-1'))).height,
      42,
    );

    await tester.tap(find.byKey(const Key('drawer-projects-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收起全部项目'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-conversation-0-1')), findsNothing);
    expect(find.byKey(const Key('drawer-conversation-1-3')), findsNothing);
    expect(find.text('项目(5)'), findsOneWidget);
    expect(tester.getRect(footer), footerRect);

    await tester.tap(find.byKey(const Key('drawer-projects-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开全部项目'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-conversation-0-1')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('drawer-project-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无历史'), findsWidgets);
    expect(tester.getRect(footer), footerRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new IP project starts with a fresh creation prompt', (
    tester,
  ) async {
    await pumpDrawer(tester);
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    expect(composer.controller.markdown, '旧草稿');
    await tester.tap(find.byKey(const Key('drawer-new-project')));
    await tester.pumpAndSettle();
    expect(composer.controller.markdown, '做一个新IP');
    expect(
      find.byKey(const Key('drawer-new-project')).hitTestable(),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('back closes the project menu before the drawer', (tester) async {
    await pumpDrawer(tester);
    await tester.tap(find.byKey(const Key('drawer-projects-menu')));
    await tester.pumpAndSettle();
    expect(find.text('展开全部项目'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('展开全部项目'), findsNothing);
    expect(
      find.byKey(const Key('drawer-new-project')).hitTestable(),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('drawer-new-project')).hitTestable(),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final language in ['zh', 'en']) {
      testWidgets('compact $language drawer supports dark mode: $dark', (
        tester,
      ) async {
        await pumpDrawer(
          tester,
          size: const Size(320, 568),
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: Locale(language),
        );
        expect(find.byKey(const Key('drawer-new-project')), findsOneWidget);
        final list = tester.getRect(
          find.byKey(const Key('drawer-project-list')),
        );
        final footer = tester.getRect(
          find.byKey(const Key('drawer-profile-button')),
        );
        expect(list.bottom, lessThan(footer.top));
        expect(footer.bottom, lessThanOrEqualTo(568));
        await tester.drag(
          find.byKey(const Key('drawer-project-list')),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('drawer-project-4')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
