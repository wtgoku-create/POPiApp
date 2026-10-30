import 'dart:async';

import 'package:flutter/material.dart';
import 'package:extended_text_field/extended_text_field.dart';
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
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'support/ip_guide_fixtures.dart';
import 'support/session_fixtures.dart';

void main() {
  late MemoryGuideStorage storage;
  late FixtureIpGuideApi api;
  late FixtureIpGuideAgentApi agent;
  late IpGuideRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = MemoryGuideStorage(await SharedPreferences.getInstance());
    api = FixtureIpGuideApi();
    agent = FixtureIpGuideAgentApi();
    repository = IpGuideRepository(storage, api, agent, userId: '1');
  });

  Future<void> pumpGuide(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    bool dark = false,
    Locale locale = const Locale('zh'),
    double textScale = 1,
    bool reducedMotion = false,
    double systemTopInset = 0,
    double safeAreaBottom = 34,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: systemTopInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final container = ProviderContainer(
      overrides: [
        ipGuideRepositoryProvider.overrideWithValue(repository),
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: '1', name: '用户', email: ''));
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(EdgeInsets.only(top: 52, bottom: safeAreaBottom));
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
    final grid = find.byType(IpGuideChoiceGrid<String>);
    expect(find.byType(IpGuideSelectionSummary), findsNothing);
    expect(tester.getTopLeft(input).dy - tester.getBottomLeft(grid).dy, 20);
    final inputTop = tester.getTopLeft(input).dy;
    await tap(tester, 'ip-direction-校园');
    expect(find.text('主方向：校园'), findsOneWidget);
    await tap(tester, 'ip-direction-校园');
    expect(find.byType(IpGuideSelectionSummary), findsNothing);
    expect(tester.getTopLeft(input).dy, inputTop);
  });

  testWidgets(
    'custom answer sheet fits above keyboard and retains limited edits',
    (tester) async {
      (api.preferenceCatalog['steps'] as List).first['maxNameBytes'] = 2000;
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

  testWidgets(
    'server catalog adds choices and controls their selection limit',
    (tester) async {
      final step =
          (api.preferenceCatalog['steps'] as List).first
              as Map<String, dynamic>;
      step['maxSelections'] = 3;
      step['options'] = [
        for (final name in ['天文观察', '城市散步', '传统工艺'])
          {'name': name, 'description': '接口新增方向', 'imageUrl': null},
      ];
      await pumpGuide(tester);
      await tap(tester, 'ip-guide-start');
      expect(api.preferenceRequests, 1);
      expect(find.text('校园'), findsNothing);
      for (final name in ['天文观察', '城市散步', '传统工艺']) {
        await tap(tester, 'ip-direction-$name');
      }
      expect(repository.load()!.preferences['contentDirections']!.values, [
        '天文观察',
        '城市散步',
        '传统工艺',
      ]);
      await tap(tester, 'ip-guide-next-1');
      expect(find.text('来自接口的选项描述'), findsWidgets);
      await tap(tester, 'ip-guide-back');
      expect(find.text('主方向：天文观察'), findsOneWidget);
      expect(api.preferenceRequests, 1);
    },
  );

  testWidgets(
    'preference request failure exposes retry without static choices',
    (tester) async {
      api.failPreferences = true;
      await pumpGuide(tester);
      await tap(tester, 'ip-guide-start');
      expect(find.text('校园'), findsNothing);
      expect(find.byKey(const Key('ip-preferences-retry')), findsOneWidget);
      expect(
        tester
            .widget<IpGuideNextButton>(find.byKey(const Key('ip-guide-next-1')))
            .onPressed,
        isNull,
      );
      api.failPreferences = false;
      await tap(tester, 'ip-preferences-retry');
      expect(api.preferenceRequests, 2);
      expect(find.text('校园'), findsOneWidget);
    },
  );

  testWidgets(
    'preference loading disables advancing until the request finishes',
    (tester) async {
      final pending = Completer<void>();
      api.preferenceWait = pending.future;
      await pumpGuide(tester);
      await tester.tap(find.byKey(const Key('ip-guide-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('ip-preferences-loading')), findsOneWidget);
      expect(
        tester
            .widget<IpGuideNextButton>(find.byKey(const Key('ip-guide-next-1')))
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('校园'), findsOneWidget);
    },
  );

  testWidgets(
    'catalog can disable custom input and restrict preset selections',
    (tester) async {
      final step =
          (api.preferenceCatalog['steps'] as List).first
              as Map<String, dynamic>;
      step['allowCustom'] = false;
      step['maxSelections'] = 1;
      await pumpGuide(tester);
      await tap(tester, 'ip-guide-start');
      expect(find.byKey(const Key('ip-custom-direction')), findsNothing);
      await tap(tester, 'ip-direction-校园');
      await tap(tester, 'ip-direction-情感');
      expect(repository.load()!.preferences['contentDirections']!.values, [
        '校园',
      ]);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('custom preference input respects the server UTF-8 byte limit', (
    tester,
  ) async {
    (api.preferenceCatalog['steps'] as List).first['maxNameBytes'] = 6;
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    await enterAnswer(tester, 'ip-custom-direction', '天文');
    await enterAnswer(tester, 'ip-custom-direction', '天文学');
    expect(
      repository.load()!.preferences['contentDirections']!.customText,
      '天文',
    );
  });

  testWidgets('optional server groups can be skipped and submit empty arrays', (
    tester,
  ) async {
    for (final step in api.preferenceCatalog['steps'] as List) {
      step['required'] = false;
    }
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    for (var step = 1; step <= 4; step++) {
      await tap(tester, 'ip-guide-next-$step');
    }
    await tester.enterText(field('ip-nickname'), '新账号');
    await tap(tester, 'ip-confirm');
    for (final key in [
      'contentDirections',
      'audienceFeelings',
      'presentationFormats',
      'targetAudience',
    ]) {
      expect(api.savedProfile![key], isEmpty);
    }
    expect(find.text('创建成功！'), findsOneWidget);
  });

  testWidgets(
    'server presentation names support multiple choices and keep canonical values in English',
    (tester) async {
      final step =
          (api.preferenceCatalog['steps'] as List)[2] as Map<String, dynamic>;
      step['options'] = [
        for (final name in ['绘本插画', '纪录片'])
          {'name': name, 'description': '新增表达形式', 'imageUrl': null},
      ];
      await pumpGuide(tester, locale: const Locale('en'));
      await tap(tester, 'ip-guide-start');
      await tap(tester, 'ip-direction-校园');
      await tap(tester, 'ip-guide-next-1');
      await tap(tester, 'ip-feeling-真实');
      await tap(tester, 'ip-guide-next-2');
      await tap(tester, 'ip-presentation-绘本插画');
      await tap(tester, 'ip-presentation-纪录片');
      await tap(tester, 'ip-guide-next-3');
      await tap(tester, 'ip-audience-学生群体');
      await tap(tester, 'ip-guide-next-4');
      expect(
        tester.widget<Text>(find.byKey(const Key('ip-review-value-2'))).data,
        contains('绘本插画 × 纪录片'),
      );
      await tester.enterText(field('ip-nickname'), '新账号');
      await tap(tester, 'ip-confirm');
      expect(api.savedProfile!['contentDirections'], ['校园']);
      expect(api.savedProfile!['presentationFormats'], ['绘本插画', '纪录片']);
    },
  );

  testWidgets('status bar inset is counted once above the guide progress', (
    tester,
  ) async {
    await pumpGuide(tester, systemTopInset: 52);
    final back = find.byKey(const Key('ip-guide-back'));
    expect(back, findsOneWidget);
    expect(find.byKey(const Key('ip-guide-menu')), findsNothing);
    expect(tester.getSize(back), const Size(40, 40));
    expect(tester.getTopLeft(back).dy, 52 + 8);
    expect(tester.widget<AppBar>(find.byType(AppBar)).actions, isNull);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).drawer, isNull);
    expect(
      tester.getTopLeft(find.byKey(const Key('ip-guide-progress'))).dy,
      52 + 56,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the initial header back button leaves the guide', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-back');
    expect(find.byType(IpGuidePage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });

  for (final bottomInset in [0.0, 16.0, 34.0]) {
    testWidgets('start action counts bottom inset once: $bottomInset', (
      tester,
    ) async {
      await pumpGuide(tester, safeAreaBottom: bottomInset);
      final action = find.byKey(const Key('ip-guide-start'));
      expect(
        tester.getBottomLeft(action).dy,
        closeTo(956 - (bottomInset < 20 ? 20 : bottomInset), .01),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'start and next actions stay at the bottom while content scrolls',
    (tester) async {
      await pumpGuide(tester, size: const Size(320, 640));
      const choices = [
        'ip-direction-校园',
        'ip-feeling-真实',
        'ip-presentation-3D动漫',
        'ip-audience-学生群体',
      ];
      for (var step = 0; step <= 4; step++) {
        final actionKey = step == 0 ? 'ip-guide-start' : 'ip-guide-next-$step';
        final action = find.byKey(Key(actionKey));
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getBottomLeft(action).dy, closeTo(640 - 34, .01));
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
      expect(tester.getBottomLeft(reselect).dy, closeTo(size.height - 34, .01));
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
      expect(tester.getBottomLeft(project).dy, closeTo(size.height - 34, .01));
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

  for (final (locale, entry) in [
    (const Locale('zh'), 'ip-create-role'),
    (const Locale('en'), 'ip-create-role'),
    (const Locale('zh'), 'ip-create-content'),
    (const Locale('en'), 'ip-create-content'),
  ]) {
    testWidgets(
      '$entry opens the created session with an editable prompt in $locale',
      (tester) async {
        final draft = IpGuideDraft()
          ..step = 5
          ..nickname = '校园故事'
          ..presentation = IpPresentation.animation3d;
        draft.directions.toggle(IpContentDirection.campus);
        draft.feelings.toggle(IpAudienceFeeling.authentic);
        draft.audience.toggle(IpTargetAudience.students);
        await repository.save(draft);
        await pumpGuide(tester, locale: locale);
        await tap(tester, 'ip-guide-start');
        await tap(tester, 'ip-draft-resume');
        await tap(tester, 'ip-confirm');
        expect(agent.requests, hasLength(1));
        await tap(tester, entry);

        final session = tester.widget<SessionPage>(find.byType(SessionPage));
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SessionPage)),
        )!;
        expect(session.sessionId, 'created-session');
        expect(agent.requests, hasLength(1));
        expect(agent.requests.single['accountId'], 'created-account');
        final prompt = entry == 'ip-create-role'
            ? l10n.ipFirstRolePrompt
            : l10n.ipFirstContentPrompt;
        expect(session.initialPrompt, prompt);
        final input = find.descendant(
          of: find.byType(SessionPage),
          matching: find.byType(ExtendedTextField),
        );
        expect(
          tester.widget<ExtendedTextField>(input).controller!.text,
          prompt,
        );
        await tester.tap(input);
        tester.testTextInput.enterText('创建一个勇敢的校园角色');
        await tester.pumpAndSettle();
        expect(
          tester.widget<ExtendedTextField>(input).controller!.text,
          '创建一个勇敢的校园角色',
        );
        expect(tester.takeException(), isNull);
      },
    );
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
      expect(find.byKey(const Key('ip-guide-back')), findsOneWidget);
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
      expect(find.byKey(const Key('ip-guide-back')), findsOneWidget);
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
      expect(find.byKey(const Key('ip-guide-back')), findsOneWidget);
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
      await tap(tester, 'ip-direction-校园');
      await tap(tester, 'ip-direction-情感');
      expect(find.text('主方向：校园'), findsOneWidget);
      expect(find.text('辅助：情感'), findsOneWidget);
      await tap(tester, 'ip-guide-next-1');
      await tap(tester, 'ip-feeling-真实');
      await tap(tester, 'ip-feeling-治愈');
      await tap(tester, 'ip-guide-back');
      expect(find.text('主方向：校园'), findsOneWidget);
      await tap(tester, 'ip-guide-next-1');
      expect(find.text('辅助：治愈'), findsOneWidget);
      await tap(tester, 'ip-guide-next-2');
      await tap(tester, 'ip-presentation-3D动漫');
      await tap(tester, 'ip-format-comicDrama');
      await tap(tester, 'ip-guide-next-3');
      await tap(tester, 'ip-audience-学生群体');
      await tap(tester, 'ip-audience-职场人群');
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
        'contentDirections': ['校园', '情感'],
        'audienceFeelings': ['真实', '治愈'],
        'presentationFormats': ['3D动漫'],
        'creativeConstraints': ['漫剧'],
        'targetAudience': ['学生群体', '职场人群'],
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
      await tap(tester, 'ip-direction-校园');
      await enterAnswer(tester, 'ip-custom-direction', '独立音乐');
      await tester.pumpAndSettle();
      expect(find.text('主方向：校园'), findsNothing);
      await tap(tester, 'ip-guide-next-1');
      await enterAnswer(tester, 'ip-custom-feeling', '好奇而轻松');
      await tap(tester, 'ip-guide-next-2');
      await tap(tester, 'ip-presentation-AI真人');
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
      await tap(tester, 'ip-direction-情感');
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
    expect(find.byKey(const Key('ip-guide-back')), findsOneWidget);
    expect(find.byKey(const Key('ip-guide-start')), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back returns through draft steps and then home', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    await tap(tester, 'ip-direction-校园');
    await tap(tester, 'ip-guide-next-1');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('主方向：校园'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ip-guide-start')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(IpGuidePage), findsNothing);
    expect(
      GoRouter.of(tester.element(find.byType(HomePage))).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the primary choice promotes the secondary', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    await tap(tester, 'ip-direction-校园');
    await tap(tester, 'ip-direction-情感');
    await tap(tester, 'ip-direction-成长');
    expect(find.text('辅助：情感'), findsOneWidget);
    await tap(tester, 'ip-direction-校园');
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
          if (step == 1) await tap(tester, 'ip-direction-校园');
          if (step == 2) await tap(tester, 'ip-feeling-真实');
          if (step == 3) await tap(tester, 'ip-presentation-3D动漫');
          if (step == 4) await tap(tester, 'ip-audience-学生群体');
          await tap(tester, key);
        }
      },
    );
  }
}
