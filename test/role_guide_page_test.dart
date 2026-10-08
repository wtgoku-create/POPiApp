import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/data/role_library_repository.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/assets/presentation/role_detail_page.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/role_guide/data/role_guide_examples.dart';
import 'package:popi_ai_app/features/role_guide/presentation/role_guide_page.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/project_fixtures.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  Future<ProviderContainer> pumpGuide(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    Locale locale = const Locale('zh'),
    bool dark = false,
    double scale = 1,
    RolePageLoader? loader,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final roles = roleGuideExamples(lookupAppLocalizations(locale));
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(FixtureProjectRepository()),
        rolePageLoaderProvider.overrideWithValue(
          loader ??
              ({required category, required page, required pageSize}) async =>
                  LibraryRolePage(
                    items: category == 'official'
                        ? roles
                        : roles.take(2).toList(),
                    page: page,
                    pageCount: 1,
                  ),
        ),
        roleDetailLoaderProvider.overrideWithValue(
          (id) async => roles.firstWhere((role) => role.id == id),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: '用户', email: '', allCoins: 200));
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.only(top: 52, bottom: 34));
    final router = container.read(routerProvider(false));
    router.go('/role-guide');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty &&
        find.byKey(const Key('role-generation-scroll')).evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('role-generation-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> selectProject(WidgetTester tester) async {
    for (var i = 1; i <= 4; i++) {
      await tap(tester, 'role-guide-select-preview-role-$i');
    }
    await tap(tester, 'role-guide-create-project');
  }

  Future<void> chooseStory(WidgetTester tester) async {
    await selectProject(tester);
    for (final i in [1, 2, 4]) {
      await tap(tester, 'role-guide-select-preview-role-$i');
    }
    await tap(tester, 'role-guide-confirm-cast');
    await tap(tester, 'role-guide-choose-story');
  }

  testWidgets('home character entry opens the guide', (tester) async {
    final container = await pumpGuide(tester);
    container.read(routerProvider(false)).go('/');
    await tester.pumpAndSettle();
    await tap(tester, 'home-start-1');
    expect(find.byType(RoleGuidePage), findsOneWidget);
    expect(find.text('从角色出发～'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'full flow preserves project, cast, story and both parameter groups',
    (tester) async {
      await pumpGuide(tester);
      await selectProject(tester);
      expect(find.text('爱丽丝的项目'), findsOneWidget);
      expect(find.text('共有4个角色'), findsOneWidget);
      for (final i in [1, 2, 4]) {
        await tap(tester, 'role-guide-select-preview-role-$i');
      }
      await tap(tester, 'role-guide-confirm-cast');
      await tap(tester, 'role-guide-next-story');
      expect(find.text('室友的秘密计划'), findsOneWidget);
      await tap(tester, 'role-guide-previous-story');
      await tap(tester, 'role-guide-edit-cast');
      expect(find.textContaining('已选3个角色'), findsOneWidget);
      await tap(tester, 'role-guide-confirm-cast');
      await tap(tester, 'role-guide-choose-story');
      await tap(tester, 'role-guide-configure');
      await tap(tester, 'role-model-veo');
      await tap(tester, 'role-resolution-1080');
      await tap(tester, 'role-ratio-portrait');
      await tap(tester, 'role-segment-1');
      expect(find.text('模型选择'), findsNothing);
      await tap(tester, 'role-ratio-square');
      await tap(tester, 'role-quantity-2');
      await tap(tester, 'role-generation-confirm');
      expect(find.text('Veo 3.1 / 1080P / 9:16'), findsOneWidget);
      await tap(tester, 'role-guide-produce');
      final session = tester.widget<SessionPage>(find.byType(SessionPage));
      expect(session.initialPrompt, contains('爱丽丝的项目'));
      expect(session.initialPrompt, contains('视频模型：Veo 3.1'));
      expect(session.initialPrompt, contains('视频参数：1080P / 9:16'));
      expect(session.initialPrompt, contains('图片参数：720P / 1:1'));
      expect(session.initialPrompt, contains('生成数量：2'));
      expect(
        session.initialPrompt,
        contains(
          '出场角色：爱丽丝 [preview-role-1], 尔尔 [preview-role-2], 水獭兜兜儿 [preview-role-4]',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'library selection is shared with the grid and survives dismissal',
    (tester) async {
      await pumpGuide(tester);
      await tap(tester, 'role-guide-select-preview-role-1');
      await tap(tester, 'role-guide-more');
      await tap(tester, 'role-library-select-preview-role-2');
      expect(find.textContaining('已选2个角色'), findsNWidgets(2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining('已选2个角色'), findsOneWidget);
      await tap(tester, 'role-guide-more');
      await tap(tester, 'role-library-create-project');
      expect(find.byKey(const Key('role-guide-library-sheet')), findsNothing);
      expect(find.text('共有2个角色'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty choices and selection limits cannot advance', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'role-guide-create-project');
    expect(find.text('选择出场角色'), findsNothing);
    for (var i = 1; i <= 7; i++) {
      await tap(tester, 'role-guide-select-preview-role-$i');
    }
    expect(find.textContaining('已选6个角色'), findsOneWidget);
    await tap(tester, 'role-guide-create-project');
    await tap(tester, 'role-guide-confirm-cast');
    expect(find.text('为TA们匹配选题'), findsNothing);
    for (var i = 1; i <= 4; i++) {
      await tap(tester, 'role-guide-select-preview-role-$i');
    }
    expect(find.textContaining('已选3个角色'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'library category changes synchronize with the grid without losing choices',
    (tester) async {
      await pumpGuide(tester);
      await tap(tester, 'role-guide-select-preview-role-3');
      await tap(tester, 'role-guide-more');
      await tester.tap(find.byKey(const Key('role-segment-1')).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('role-library-select-preview-role-3')),
        findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('role-guide-select-preview-role-3')),
        findsNothing,
      );
      expect(find.textContaining('已选1个角色'), findsOneWidget);
      await tap(tester, 'role-segment-0');
      await tap(tester, 'role-guide-create-project');
      expect(find.text('花西冷少的项目'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sheet cancellation discards edits and system back preserves draft',
    (tester) async {
      await pumpGuide(tester);
      await chooseStory(tester);
      await tap(tester, 'role-guide-configure');
      await tap(tester, 'role-model-kling');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('模型/参数（待选择）'), findsOneWidget);
      await tap(tester, 'role-guide-configure');
      await tap(tester, 'role-generation-confirm');
      expect(find.text('Sora 2 / 720P / 16:9'), findsOneWidget);
      await tap(tester, 'role-guide-configure');
      await tap(tester, 'role-model-veo');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Sora 2 / 720P / 16:9'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role-guide-choose-story')), findsOneWidget);
      await tap(tester, 'role-guide-refresh-stories');
      expect(find.text('第一次勇敢说出心里话'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining('已选3个角色'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining('已选4个角色'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('thumbnail label opens the existing role profile', (
    tester,
  ) async {
    final container = await pumpGuide(tester);
    await tap(tester, 'role-guide-details-preview-role-1');
    expect(find.byType(RoleDetailPage), findsOneWidget);
    await tap(tester, 'role-profile-back');
    expect(find.byType(RoleGuidePage), findsOneWidget);
    expect(container.read(routerProvider(false)).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed role request retries and full library can fetch another page',
    (tester) async {
      final roles = roleGuideExamples(
        lookupAppLocalizations(const Locale('zh')),
      );
      var failed = false;
      await pumpGuide(
        tester,
        loader: ({required category, required page, required pageSize}) async {
          if (!failed) {
            failed = true;
            throw StateError('Offline');
          }
          return LibraryRolePage(
            items: page == 1 ? roles.take(4).toList() : roles.skip(4).toList(),
            page: page,
            pageCount: 2,
          );
        },
      );
      expect(find.byKey(const Key('role-guide-retry')), findsOneWidget);
      await tap(tester, 'role-guide-retry');
      await tap(tester, 'role-guide-more');
      await tap(tester, 'role-guide-load-more');
      expect(
        find.byKey(const Key('role-library-select-preview-role-8')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late category responses cannot overwrite current category', (
    tester,
  ) async {
    final pending = Completer<LibraryRolePage>();
    final roles = roleGuideExamples(lookupAppLocalizations(const Locale('zh')));
    var officialRequests = 0;
    await pumpGuide(
      tester,
      loader: ({required category, required page, required pageSize}) async {
        if (category == 'official' && ++officialRequests > 1) {
          return pending.future;
        }
        return LibraryRolePage(
          items: category == 'official' ? roles : const [],
          page: page,
          pageCount: 1,
        );
      },
    );
    await tap(tester, 'role-segment-1');
    expect(find.text('暂无我的角色'), findsOneWidget);
    await tester.tap(find.byKey(const Key('role-segment-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('role-segment-1')));
    await tester.pumpAndSettle();
    pending.complete(LibraryRolePage(items: roles, page: 1, pageCount: 1));
    await tester.pumpAndSettle();
    expect(find.text('暂无我的角色'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets('English dark flow fits $size with large text', (tester) async {
      await pumpGuide(
        tester,
        size: size,
        dark: true,
        locale: const Locale('en'),
        scale: 1.4,
      );
      expect(tester.takeException(), isNull);
      await chooseStory(tester);
      expect(tester.takeException(), isNull);
      await tap(tester, 'role-guide-configure');
      await tap(tester, 'role-ratio-portrait');
      await tap(tester, 'role-generation-confirm');
      expect(find.text('Sora 2 / 720P / 9:16'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
