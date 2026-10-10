import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/ip_guide/presentation/ip_guide_page.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/ip_guide/data/ip_guide_repository.dart';
import 'package:popi_ai_app/features/ip_guide/domain/ip_guide_draft.dart';
import 'package:popi_ai_app/features/ip_guide/presentation/widgets/ip_guide_choices.dart';
import 'package:popi_ai_app/features/ip_guide/presentation/widgets/ip_guide_controls.dart';
import 'package:popi_ai_app/shared/providers/ip_guide_provider.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'support/ip_guide_fixtures.dart';

void main() {
  late MemoryGuideStorage storage;
  late FixtureIpGuideApi api;
  late IpGuideRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = MemoryGuideStorage(await SharedPreferences.getInstance());
    api = FixtureIpGuideApi();
    repository = IpGuideRepository(storage, api, userId: '1');
  });

  Future<void> pumpGuide(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    bool dark = false,
    Locale locale = const Locale('zh'),
    double textScale = 1,
    bool reducedMotion = false,
    double systemTopInset = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: systemTopInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final container = ProviderContainer(
      overrides: [ipGuideRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: '用户', email: ''));
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.only(top: 52, bottom: 34));
    final router = container.read(routerProvider(false));
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
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('home-start-0')));
    await tester.tap(find.byKey(const Key('home-start-0')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );

  Future<void> enterAnswer(WidgetTester tester, String key, String text) async {
    await tap(tester, key);
    expect(find.byKey(const Key('popi-expanded-editor')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('ip-guide-expanded-input')),
      text,
    );
    await tap(tester, 'ip-guide-editor-confirm');
  }

  testWidgets('empty selections leave only the normal gap above custom input', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    final input = field('ip-custom-direction');
    final grid = find.byType(IpGuideChoiceGrid<IpContentDirection>);
    expect(find.byType(IpGuideSelectionSummary), findsNothing);
    expect(tester.getTopLeft(input).dy - tester.getBottomLeft(grid).dy, 20);
    final inputTop = tester.getTopLeft(input).dy;
    await tap(tester, 'ip-direction-campus');
    expect(find.text('主方向：校园'), findsOneWidget);
    await tap(tester, 'ip-direction-campus');
    expect(find.byType(IpGuideSelectionSummary), findsNothing);
    expect(tester.getTopLeft(input).dy, inputTop);
  });

  testWidgets(
    'custom answer sheet fits above keyboard and retains limited edits',
    (tester) async {
      await pumpGuide(tester, size: const Size(320, 640));
      await tap(tester, 'ip-guide-start');
      final inlineInput = field('ip-custom-direction');
      expect(tester.widget<TextField>(inlineInput).readOnly, isTrue);
      await tap(tester, 'ip-custom-direction');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final editor = find.byKey(const Key('popi-expanded-editor'));
      final expandedInput = find.byKey(const Key('ip-guide-expanded-input'));
      expect(tester.getBottomLeft(editor).dy, lessThanOrEqualTo(400));
      expect(tester.widget<TextField>(expandedInput).maxLength, 50);
      await tester.enterText(expandedInput, List.filled(51, '👩‍🎨').join());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(expandedInput)
            .controller!
            .text
            .characters
            .length,
        50,
      );
      await tap(tester, 'ip-guide-editor-confirm');
      expect(editor, findsNothing);
      expect(repository.load()!.directions.customText.characters.length, 50);
      await tap(tester, 'ip-custom-direction');
      await tester.enterText(expandedInput, '独立音乐\n日常创作');
      await tap(tester, 'popi-expanded-editor-close');
      expect(
        tester.widget<TextField>(inlineInput).controller!.text,
        '独立音乐\n日常创作',
      );
      await tap(tester, 'ip-custom-direction');
      await tester.enterText(expandedInput, '修改后保留');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      expect(repository.load()!.directions.customText, '修改后保留');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('status bar inset is counted once above the guide progress', (
    tester,
  ) async {
    await pumpGuide(tester, systemTopInset: 52);
    final menu = find.byKey(const Key('ip-guide-menu'));
    expect(find.byKey(const Key('ip-guide-back')), findsNothing);
    expect(tester.getSize(menu), const Size(40, 40));
    expect(tester.getTopLeft(menu).dy, 52 + 8);
    expect(
      tester.getTopLeft(find.byKey(const Key('ip-guide-progress'))).dy,
      52 + 56,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'start and next actions stay at the bottom while content scrolls',
    (tester) async {
      await pumpGuide(tester, size: const Size(320, 640));
      const choices = [
        'ip-direction-campus',
        'ip-feeling-authentic',
        'ip-presentation-animation3d',
        'ip-audience-students',
      ];
      for (var step = 0; step <= 4; step++) {
        final actionKey = step == 0 ? 'ip-guide-start' : 'ip-guide-next-$step';
        final action = find.byKey(Key(actionKey));
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getBottomLeft(action).dy, closeTo(640 - 34 - 20, .01));
        final position = tester.getTopLeft(action);
        await tester.drag(
          find.byKey(Key('ip-guide-scroll-$step')),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(action), position);
        if (step > 0) await tap(tester, choices[step - 1]);
        await tap(tester, actionKey);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'next action stays above the keyboard and custom input is reachable',
    (tester) async {
      await pumpGuide(tester, size: const Size(320, 640));
      await tap(tester, 'ip-guide-start');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('ip-guide-next-1'));
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(action).dy, closeTo(640 - 240 - 20, .01));
      final input = field('ip-custom-direction');
      await tester.ensureVisible(input);
      await tester.pumpAndSettle();
      expect(input.hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(input).dy,
        lessThan(tester.getTopLeft(action).dy),
      );
      await enterAnswer(tester, 'ip-custom-direction', '独立音乐');
      await tap(tester, 'ip-guide-next-1');
      expect(find.text('你想让观众看完有什么感受？'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('review actions stay fixed while summary scrolls at $size', (
      tester,
    ) async {
      final draft = IpGuideDraft()
        ..step = 5
        ..nickname = '校园故事'
        ..presentation = IpPresentation.animation3d;
      draft.directions.toggle(IpContentDirection.campus);
      draft.feelings.toggle(IpAudienceFeeling.authentic);
      draft.audience.toggle(IpTargetAudience.students);
      await repository.save(draft);
      await pumpGuide(tester, size: size);
      await tap(tester, 'ip-guide-start');
      await tap(tester, 'ip-draft-resume');

      final confirm = find.byKey(const Key('ip-confirm'));
      final reselect = find.byKey(const Key('ip-reselect'));
      expect(confirm.hitTestable(), findsOneWidget);
      expect(reselect.hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(reselect).dy,
        closeTo(size.height - 34 - 20, .01),
      );
      final confirmPosition = tester.getTopLeft(confirm);
      final reselectPosition = tester.getTopLeft(reselect);
      final summaryPosition = tester.getTopLeft(
        find.byKey(const Key('ip-review-panel')),
      );
      await tester.drag(
        find.byKey(const Key('ip-guide-scroll-5')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(confirm), confirmPosition);
      expect(tester.getTopLeft(reselect), reselectPosition);
      expect(
        tester.getTopLeft(find.byKey(const Key('ip-review-panel'))).dy,
        lessThan(summaryPosition.dy),
      );
      expect(
        tester.getBottomLeft(find.byKey(const Key('ip-guide-scroll-5'))).dy,
        lessThan(confirmPosition.dy),
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(reselect).dy,
        closeTo(size.height - 240 - 20, .01),
      );
      final nickname = field('ip-nickname');
      await tester.ensureVisible(nickname);
      await tester.pumpAndSettle();
      expect(nickname.hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(nickname).dy,
        lessThanOrEqualTo(tester.getTopLeft(confirm).dy),
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final project = find.byKey(const Key('ip-open-project'));
      expect(project.hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(project).dy,
        closeTo(size.height - 34 - 20, .01),
      );
      final projectPosition = tester.getTopLeft(project);
      await tester.drag(
        find.byKey(const Key('ip-guide-scroll-5')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(project), projectPosition);
      expect(
        find.byKey(const Key('ip-create-role')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ip-create-content')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'checks drafts only after starting, resumes and replaces the single draft',
    (tester) async {
      final draft = IpGuideDraft()..step = 2;
      draft.directions.toggle(IpContentDirection.campus);
      draft.feelings.customText = '温暖';
      await repository.save(draft);
      await pumpGuide(tester);
      expect(storage.readCount, 0);
      expect(find.text('继续草稿，还是新建IP？'), findsNothing);
      expect(find.byKey(const Key('ip-guide-back')), findsNothing);
      await tap(tester, 'ip-guide-start');
      expect(storage.readCount, 1);
      expect(find.text('继续草稿，还是新建IP？'), findsOneWidget);
      await tap(tester, 'ip-draft-resume');
      expect(find.text('你想让观众看完有什么感受？'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('ip-custom-feeling')).controller!.text,
        '温暖',
      );
      for (var i = 0; i < 2; i++) {
        await tap(tester, 'ip-guide-back');
      }
      expect(find.byKey(const Key('ip-guide-back')), findsNothing);
      expect(find.text('继续草稿，还是新建IP？'), findsNothing);
      await tap(tester, 'ip-guide-start');
      expect(find.text('继续草稿，还是新建IP？'), findsOneWidget);
      await tap(tester, 'ip-draft-restart');
      expect(find.text('你想长期分享什么？'), findsOneWidget);
      expect(repository.load()!.directions.isEmpty, isTrue);
      expect(repository.load()!.feelings.isEmpty, isTrue);
      expect(storage.values.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismissal keeps the saved draft and retry clears it after success',
    (tester) async {
      final draft = IpGuideDraft()
        ..step = 5
        ..presentation = IpPresentation.clay
        ..nickname = '校园故事';
      draft.directions.toggle(IpContentDirection.campus);
      draft.feelings.toggle(IpAudienceFeeling.authentic);
      draft.audience.toggle(IpTargetAudience.students);
      await repository.save(draft);
      await pumpGuide(tester);
      expect(find.text('继续草稿，还是新建IP？'), findsNothing);
      await tap(tester, 'ip-guide-start');
      expect(find.text('继续草稿，还是新建IP？'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('继续草稿，还是新建IP？'), findsNothing);
      expect(find.byKey(const Key('ip-guide-back')), findsNothing);
      expect(repository.load()!.nickname, '校园故事');
      await tap(tester, 'ip-guide-start');
      await tap(tester, 'ip-draft-resume');
      api.failProfile = true;
      await tap(tester, 'ip-confirm');
      expect(repository.load()!.accountId, 'created-account');
      expect(find.text('创建成功！'), findsNothing);
      expect(find.byKey(const Key('ip-reselect')), findsNothing);
      api.failProfile = false;
      await tap(tester, 'ip-confirm');
      expect(find.text('创建成功！'), findsOneWidget);
      expect(repository.load(), isNull);
      expect(api.accountRequests, hasLength(1));
      expect(api.profileRequests[0], api.profileRequests[1]);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('progress only displays the current step and cannot navigate', (
    tester,
  ) async {
    await pumpGuide(tester);
    for (var step = 0; step < 5; step++) {
      final indicator = find.byKey(Key('ip-guide-progress-$step'));
      final semantics = tester.widget<Semantics>(indicator).properties;
      expect(semantics.selected, isFalse);
      expect(semantics.button, isNot(true));
      expect(semantics.onTap, isNull);
      await tester.tap(indicator);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ip-guide-start')), findsOneWidget);
    }
    await tap(tester, 'ip-guide-start');
    await tester.tap(find.byKey(const Key('ip-guide-progress-0')));
    await tester.pumpAndSettle();
    expect(find.text('你想长期分享什么？'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('ip-guide-progress-0')))
          .properties
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all five steps preserve selections and save the exact account profile',
    (tester) async {
      await pumpGuide(tester);
      expect(find.byType(IpGuidePage), findsOneWidget);
      expect(find.textContaining('帮你创建IP账号'), findsOneWidget);
      await tap(tester, 'ip-guide-start');
      await tap(tester, 'ip-direction-campus');
      await tap(tester, 'ip-direction-emotion');
      expect(find.text('主方向：校园'), findsOneWidget);
      expect(find.text('辅助：情感'), findsOneWidget);
      await tap(tester, 'ip-guide-next-1');
      await tap(tester, 'ip-feeling-authentic');
      await tap(tester, 'ip-feeling-healing');
      await tap(tester, 'ip-guide-back');
      expect(find.text('主方向：校园'), findsOneWidget);
      await tap(tester, 'ip-guide-next-1');
      expect(find.text('辅助：治愈'), findsOneWidget);
      await tap(tester, 'ip-guide-next-2');
      await tap(tester, 'ip-presentation-animation3d');
      await tap(tester, 'ip-format-comicDrama');
      await tap(tester, 'ip-guide-next-3');
      await tap(tester, 'ip-audience-students');
      await tap(tester, 'ip-audience-workers');
      await tap(tester, 'ip-guide-next-4');
      expect(find.text('校园 × 情感'), findsOneWidget);
      expect(find.text('真实 / 治愈'), findsOneWidget);
      expect(find.text('3D动漫 · 漫剧'), findsOneWidget);
      await tester.enterText(field('ip-nickname'), '校园小故事');
      await tester.pumpAndSettle();
      expect(find.text('校园小故事'), findsNWidgets(2));
      await tap(tester, 'ip-confirm');
      expect(find.text('创建成功！'), findsOneWidget);
      expect(api.savedProfile, {
        'contentDirection': '校园 × 情感',
        'audienceFeeling': '真实 / 治愈',
        'presentation': '3D动漫',
        'contentFormat': '漫剧',
        'targetAudience': '学生群体 × 职场人群',
      });
      expect(repository.load(), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'back navigation retains custom answers and fields enforce character limits',
    (tester) async {
      await pumpGuide(tester);
      await tap(tester, 'ip-guide-start');
      await tap(tester, 'ip-direction-campus');
      await enterAnswer(tester, 'ip-custom-direction', '独立音乐');
      await tester.pumpAndSettle();
      expect(find.text('主方向：校园'), findsNothing);
      await tap(tester, 'ip-guide-next-1');
      await enterAnswer(tester, 'ip-custom-feeling', '好奇而轻松');
      await tap(tester, 'ip-guide-next-2');
      await tap(tester, 'ip-presentation-aiReal');
      await enterAnswer(tester, 'ip-custom-format', '音乐故事');
      await tap(tester, 'ip-guide-next-3');
      await enterAnswer(tester, 'ip-custom-audience', '独立音乐爱好者');
      await tap(tester, 'ip-guide-next-4');
      expect(find.text('独立音乐'), findsOneWidget);
      expect(find.text('好奇而轻松'), findsOneWidget);
      expect(find.text('AI真人 · 音乐故事'), findsOneWidget);
      await tester.enterText(field('ip-nickname'), 'abcdefghijklmnop');
      await tester.pump();
      expect(
        tester.widget<TextField>(field('ip-nickname')).controller!.text,
        'abcdefghijklmno',
      );
      for (var i = 0; i < 4; i++) {
        await tap(tester, 'ip-guide-back');
      }
      expect(
        tester.widget<TextField>(field('ip-custom-direction')).controller!.text,
        '独立音乐',
      );
      await enterAnswer(
        tester,
        'ip-custom-direction',
        List.filled(51, 'a').join(),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(field('ip-custom-direction'))
            .controller!
            .text
            .length,
        50,
      );
      await tap(tester, 'ip-direction-emotion');
      expect(
        tester.widget<TextField>(field('ip-custom-direction')).controller!.text,
        isEmpty,
      );
      expect(find.text('主方向：情感'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing answers cannot advance or create a session', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    await tap(tester, 'ip-guide-next-1');
    expect(find.text('你想长期分享什么？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ip-guide-progress-4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ip-confirm')), findsNothing);
    expect(find.byType(SessionPage), findsNothing);
    expect(find.text('你想长期分享什么？'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tap(tester, 'ip-guide-back');
    expect(find.byKey(const Key('ip-guide-back')), findsNothing);
    expect(find.byKey(const Key('ip-guide-start')), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system back preserves the draft without restoring the replaced home',
    (tester) async {
      await pumpGuide(tester);
      await tap(tester, 'ip-guide-start');
      await tap(tester, 'ip-direction-campus');
      await tap(tester, 'ip-guide-next-1');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('主方向：校园'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ip-guide-start')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(IpGuidePage), findsOneWidget);
      expect(
        GoRouter.of(tester.element(find.byType(IpGuidePage))).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('removing the primary choice promotes the secondary', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    await tap(tester, 'ip-direction-campus');
    await tap(tester, 'ip-direction-emotion');
    await tap(tester, 'ip-direction-growth');
    expect(find.text('辅助：情感'), findsOneWidget);
    await tap(tester, 'ip-direction-campus');
    expect(find.text('主方向：情感'), findsOneWidget);
    expect(find.text('辅助：情感'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'all English dark steps fit $size with large text and reduced motion',
      (tester) async {
        await pumpGuide(
          tester,
          size: size,
          dark: true,
          locale: const Locale('en'),
          textScale: 1.3,
          reducedMotion: true,
        );
        expect(
          tester
              .widget<TabBarView>(find.byType(TabBarView))
              .controller!
              .animationDuration,
          Duration.zero,
        );
        for (var step = 0; step < 6; step++) {
          final key = step == 0
              ? 'ip-guide-start'
              : step == 5
              ? 'ip-confirm'
              : 'ip-guide-next-$step';
          await tester.ensureVisible(find.byKey(Key(key)));
          await tester.pumpAndSettle();
          expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (step == 5) continue;
          if (step == 1) await tap(tester, 'ip-direction-campus');
          if (step == 2) await tap(tester, 'ip-feeling-authentic');
          if (step == 3) await tap(tester, 'ip-presentation-animation3d');
          if (step == 4) await tap(tester, 'ip-audience-students');
          await tap(tester, key);
        }
      },
    );
  }
}
