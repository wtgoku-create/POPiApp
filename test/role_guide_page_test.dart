import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/assets/presentation/role_detail_page.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/role_guide/data/role_guide_examples.dart';
import 'package:popi_ai_app/features/role_guide/presentation/role_guide_page.dart';
import 'package:popi_ai_app/features/role_guide/data/role_generation_repository.dart';
import 'package:popi_ai_app/features/role_guide/domain/role_generation.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/project_fixtures.dart';
import 'support/role_library_fixtures.dart';
import 'support/session_fixtures.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  Future<ProviderContainer> pumpGuide(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    Locale locale = const Locale('zh'),
    bool dark = false,
    double scale = 1,
    double systemTopInset = 0,
    RolePageLoader? loader,
    RoleGenerationRepository? generationRepository,
    ProjectRepository? projectRepository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: systemTopInset);
    tester.view.viewPadding = FakeViewPadding(top: systemTopInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final roles = roleGuideExamples(lookupAppLocalizations(locale));
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
        projectRepositoryProvider.overrideWithValue(
          projectRepository ?? FixtureProjectRepository(),
        ),
        dioProvider.overrideWithValue(
          roleLibraryDio(
            loadPage:
                loader ??
                ({required category, required page, required pageSize}) async =>
                    LibraryRolePage(
                      items: category == 'official'
                          ? roles
                          : roles.take(2).toList(),
                      page: page,
                      pageCount: 1,
                    ),
            loadDetail: (id) async => roles.firstWhere((role) => role.id == id),
          ),
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
    if (generationRepository != null) {
      unawaited(
        Navigator.of(tester.element(find.byType(RoleGuidePage))).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                RoleGuidePage(generationRepository: generationRepository),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
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
    await tap(tester, 'role-guide-choose-story');
  }

  testWidgets('app bar counts the device top inset only once', (tester) async {
    await pumpGuide(tester, systemTopInset: 52);
    expect(tester.getSize(find.byType(AppBar)).height, 56);
    expect(tester.getTopLeft(find.byType(AppBar)).dy, 52);
    expect(
      tester.getTopLeft(find.byKey(const Key('role-guide-scroll'))).dy,
      52 + 56,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'step actions stay at the bottom while planning content scrolls',
    (tester) async {
      await pumpGuide(tester, size: const Size(320, 640));

      Future<void> checkFooter(
        String bottomAction,
        List<String> actions,
      ) async {
        final bottom = find.byKey(Key(bottomAction));
        expect(tester.getBottomLeft(bottom).dy, closeTo(640 - 34 - 20, .01));
        final positions = {
          for (final key in actions)
            key: tester.getTopLeft(find.byKey(Key(key))),
        };
        await tester.drag(
          find.byKey(const Key('role-guide-scroll')),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        for (final key in actions) {
          final action = find.byKey(Key(key));
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getTopLeft(action), positions[key]);
        }
        expect(tester.takeException(), isNull);
      }

      await checkFooter('role-guide-create-project', [
        'role-guide-create-project',
      ]);
      await selectProject(tester);
      await checkFooter('role-guide-refresh-stories', [
        'role-guide-choose-story',
        'role-guide-refresh-stories',
      ]);
      await tap(tester, 'role-guide-refresh-stories');
      await tap(tester, 'role-guide-choose-story');
      await checkFooter('role-guide-produce', ['role-guide-produce']);
      await tap(tester, 'role-guide-produce');
      expect(find.byKey(const Key('role-generation-scroll')), findsOneWidget);
      await tap(tester, 'role-generation-confirm');
      await checkFooter('role-guide-produce', ['role-guide-produce']);
      await tap(tester, 'role-guide-produce');
      expect(find.text('生成成功！'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('step action stays above the keyboard inset', (tester) async {
    await pumpGuide(tester, size: const Size(320, 640));
    await tap(tester, 'role-guide-select-preview-role-1');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('role-guide-create-project'));
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(action).dy, closeTo(640 - 240 - 20, .01));
    await tap(tester, 'role-guide-create-project');
    expect(
      find.byKey(const Key('role-guide-choose-story')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home character entry opens the guide', (tester) async {
    final container = await pumpGuide(tester);
    container.read(routerProvider(false)).go('/');
    await tester.pumpAndSettle();
    await tap(tester, 'home-start-1');
    expect(find.byType(RoleGuidePage), findsOneWidget);
    expect(find.text('从角色出发'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'full flow preserves project, cast, story and both parameter groups',
    (tester) async {
      await pumpGuide(tester);
      await selectProject(tester);
      expect(find.text('爱丽丝的项目'), findsOneWidget);
      expect(find.text('共4个角色'), findsOneWidget);
      await tap(tester, 'role-guide-next-story');
      expect(find.text('室友的秘密计划'), findsOneWidget);
      await tap(tester, 'role-guide-previous-story');
      await tap(tester, 'role-guide-edit-cast');
      await tap(tester, 'role-library-select-preview-role-3');
      expect(find.textContaining('已选3个角色'), findsOneWidget);
      await tap(tester, 'role-library-create-project');
      await tap(tester, 'role-guide-choose-story');
      expect(find.text('开始创作'), findsOneWidget);
      expect(find.byKey(const Key('role-guide-refresh-stories')), findsNothing);
      expect(find.text('查看方案'), findsNothing);
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
      expect(find.text('生成成功！'), findsOneWidget);
      expect(find.text('交互演示 · 不消耗积分'), findsOneWidget);
      await tap(tester, 'role-guide-view-plan');
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
      expect(find.text('共2个角色'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'role library title and controls remain fixed while roles scroll',
    (tester) async {
      await pumpGuide(tester);
      await tap(tester, 'role-guide-more');
      final title = find.text('角色库');
      final controls = find.byKey(const Key('role-guide-library-controls'));
      final create = find.descendant(
        of: controls,
        matching: find.byKey(const Key('role-guide-create-role')),
      );
      final titleBounds = tester.getRect(title);
      final controlsBounds = tester.getRect(controls);
      final createBounds = tester.getRect(create);
      final list = find.byKey(const Key('role-guide-library-scroll'));
      final controller = tester.widget<ListView>(list).controller!;
      expect(controller.offset, 0);
      await tester.drag(
        find.byKey(const Key('role-guide-library-scroll')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(title), titleBounds);
      expect(tester.getRect(controls), controlsBounds);
      expect(tester.getRect(create), createBounds);
      expect(controller.offset, greaterThan(0));
      await tester.tap(
        find.descendant(
          of: controls,
          matching: find.byKey(const Key('role-segment-1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(controls), controlsBounds);
      expect(
        find.byKey(const Key('role-library-select-preview-role-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('role-library-select-preview-role-3')),
        findsNothing,
      );
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
    expect(find.textContaining('已选5个角色'), findsOneWidget);
    await tap(tester, 'role-guide-create-project');
    expect(find.text('匹配选题'), findsOneWidget);
    expect(find.text('共5个角色'), findsOneWidget);
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

  testWidgets('project role edits cancel without changing the selected story', (
    tester,
  ) async {
    await pumpGuide(tester);
    await selectProject(tester);
    await tap(tester, 'role-guide-next-story');
    await tap(tester, 'role-guide-edit-cast');
    await tap(tester, 'role-library-select-preview-role-1');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('共4个角色'), findsOneWidget);
    expect(find.text('室友的秘密计划'), findsOneWidget);
    expect(find.text('爱丽丝的项目'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'character profiles paginate and full profile returns to the story',
    (tester) async {
      await pumpGuide(tester);
      await selectProject(tester);
      await tap(tester, 'role-guide-view-profiles');
      expect(find.text('角色档案 1/4'), findsOneWidget);
      await tap(tester, 'role-profile-next');
      expect(find.text('角色档案 2/4'), findsOneWidget);
      expect(find.text('人物定位'), findsOneWidget);
      await tap(tester, 'role-guide-full-profile');
      final page = tester.widget<RoleDetailPage>(find.byType(RoleDetailPage));
      expect(page.role.id, 'preview-role-2');
      await tap(tester, 'role-profile-back');
      expect(find.byKey(const Key('role-guide-profile-sheet')), findsNothing);
      expect(find.text('匹配选题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [292.0, 390.0, 440.0]) {
    testWidgets('story title stays on one line at width $width', (
      tester,
    ) async {
      await pumpGuide(tester, size: Size(width, 956));
      await selectProject(tester);
      final title = lookupAppLocalizations(
        const Locale('zh'),
      ).roleExampleStoryTitle1;
      final heading = find.text(title);

      void expectSingleLine() {
        final paragraph = tester.renderObject<RenderParagraph>(heading);
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: title.length),
        );
        expect(boxes, isNotEmpty);
        expect(boxes.map((box) => box.top).toSet(), hasLength(1));
        expect(tester.getSize(heading).height, lessThan(30));
      }

      expectSingleLine();
      await tap(tester, 'role-guide-choose-story');
      expectSingleLine();
      expect(
        tester.getRect(heading).right,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const Key('role-guide-story-details')))
              .left,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('detailed story exposes the plot and complete storyboard', (
    tester,
  ) async {
    await pumpGuide(tester);
    await chooseStory(tester);
    await tap(tester, 'role-guide-story-details');
    expect(find.byKey(const Key('role-guide-story-sheet')), findsOneWidget);
    expect(find.text('主要内容'), findsOneWidget);
    final story = roleGuideStories(
      lookupAppLocalizations(const Locale('zh')),
      0,
    ).first;
    expect(find.text(story.content), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-guide-produce')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stop confirmation cancels generation and retains model settings',
    (tester) async {
      await pumpGuide(tester);
      await chooseStory(tester);
      await tap(tester, 'role-guide-configure');
      await tap(tester, 'role-model-veo');
      await tap(tester, 'role-generation-confirm');
      await tester.ensureVisible(find.byKey(const Key('role-guide-produce')));
      await tester.tap(find.byKey(const Key('role-guide-produce')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('努力生成中...'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('role-guide-generation-action')),
      );
      await tester.tap(find.byKey(const Key('role-guide-generation-action')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('role-guide-confirm-stop')));
      await tester.pumpAndSettle();
      expect(find.text('已停止制作'), findsOneWidget);
      await tap(tester, 'role-guide-back');
      expect(find.text('Veo 3.1 / 720P / 16:9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed generation can retry the same plan and continue creating',
    (tester) async {
      final repository = _RetryGenerationRepository();
      await pumpGuide(tester, generationRepository: repository);
      await chooseStory(tester);
      await tap(tester, 'role-guide-configure');
      await tap(tester, 'role-generation-confirm');
      await tap(tester, 'role-guide-produce');
      expect(find.text('生成未完成'), findsOneWidget);
      await tap(tester, 'role-guide-generation-action');
      expect(find.text('生成成功！'), findsOneWidget);
      expect(repository.plans.length, 2);
      expect(repository.plans[0], repository.plans[1]);
      await tap(tester, 'role-guide-generation-action');
      expect(find.text('第一次勇敢说出心里话'), findsOneWidget);
      expect(find.text('共4个角色'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching projects opens an existing project conversation', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'role-guide-switch-project');
    expect(find.text('我的IP项目'), findsOneWidget);
    await tap(tester, 'role-project-select-0');
    await tap(tester, 'role-project-confirm');
    expect(tester.widget<SessionPage>(find.byType(SessionPage)).sessionId, '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an empty project creates one conversation and waits for it to finish',
    (tester) async {
      final repository = _EmptyProjectRepository();
      await pumpGuide(tester, projectRepository: repository);
      await tap(tester, 'role-guide-switch-project');
      await tap(tester, 'role-project-select-0');
      await tap(tester, 'role-project-confirm');
      expect(repository.requestIds, hasLength(1));
      expect(find.byType(SessionPage), findsNothing);
      repository.pending.complete(
        const ProjectSession(id: 'new-session', title: 'New'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SessionPage>(find.byType(SessionPage)).sessionId,
        'new-session',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed role request retries and full library fills a short first page',
    (tester) async {
      final roles = roleGuideExamples(
        lookupAppLocalizations(const Locale('zh')),
      );
      var failed = false;
      final pages = <int>[];
      await pumpGuide(
        tester,
        loader: ({required category, required page, required pageSize}) async {
          pages.add(page);
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
      expect(pages.where((page) => page == 2), hasLength(1));
      await tester.scrollUntilVisible(
        find.byKey(const Key('role-library-select-preview-role-8')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('role-guide-library-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
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

  for (final width in [320.0, 390.0, 440.0]) {
    testWidgets('create role stays on one line at width $width', (
      tester,
    ) async {
      await pumpGuide(tester, size: Size(width, 956));
      final create = find.byKey(const Key('role-guide-create-role'));
      final label = find.descendant(of: create, matching: find.text('创建角色'));
      final buttonRect = tester.getRect(create);
      expect(buttonRect.width, 117);
      expect(buttonRect.height, 40);
      expect(tester.getSize(label).height, lessThan(25));
      expect(buttonRect.contains(tester.getCenter(label)), isTrue);
      final categoriesRect = tester.getRect(
        find.byKey(const Key('role-segment-0')),
      );
      if (width >= 390) {
        expect(buttonRect.center.dy, categoriesRect.center.dy);
      } else {
        expect(buttonRect.top, greaterThan(categoriesRect.bottom));
      }
      await tap(tester, 'role-guide-create-role');
      expect(find.byType(SessionPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
      await tap(tester, 'role-guide-story-details');
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tap(tester, 'role-guide-produce');
      expect(find.text('Creation complete!'), findsOneWidget);
      await tap(tester, 'role-guide-view-profiles');
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

class _RetryGenerationRepository extends RoleGenerationRepository {
  final plans = <String>[];

  @override
  bool get isPreview => true;

  @override
  Stream<RoleGenerationProgress> generate(String plan) {
    plans.add(plan);
    if (plans.length == 1) return Stream.error(StateError('Offline'));
    return Stream.value(
      const RoleGenerationProgress(
        status: RoleGenerationStatus.completed,
        stage: 5,
        cover: 'assets/images/role_guide_result_preview.png',
      ),
    );
  }
}

class _EmptyProjectRepository extends FixtureProjectRepository {
  final pending = Completer<ProjectSession>();
  final requestIds = <String>[];

  @override
  Future<List<ProjectSession>> listSessions(
    String projectId, {
    CancelToken? cancelToken,
  }) async => [];

  @override
  Future<ProjectSession> createSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) {
    requestIds.add(clientRequestId);
    return pending.future;
  }
}
