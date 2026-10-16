import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/role_guide/presentation/role_guide_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_skeleton.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

import 'support/home_creation_fixtures.dart';
import 'support/fake_video_player.dart';

Future<ProviderContainer> pumpLive(
  WidgetTester tester,
  HomeCreationFixture fixture, {
  Size size = const Size(390, 844),
  String route = '/role-guide',
  Locale locale = const Locale('zh'),
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(fixture.business),
      agentDioProvider.overrideWithValue(fixture.agent),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(userProvider.notifier)
      .setUser(const User(id: 'user', name: 'Test', email: ''));
  container
      .read(safeAreaInsetsProvider.notifier)
      .update(const EdgeInsets.only(top: 30, bottom: 20));
  final router = container.read(routerProvider(false));
  addTearDown(router.dispose);
  router.go(route);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: dark ? AppTheme.dark : AppTheme.light,
        routerConfig: router,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapLive(
  WidgetTester tester,
  String key, {
  bool running = false,
}) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  if (running) {
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  if (running) {
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('project summary uses account detail independently of the cast', (
    tester,
  ) async {
    final fixture = HomeCreationFixture();
    await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
    final summary = find.byKey(const Key('role-guide-project-profile'));
    expect(
      find.descendant(of: summary, matching: find.text('Account 101')),
      findsOneWidget,
    );
    expect(find.text('Character 1的项目'), findsNothing);
    final avatar = tester.widget<Image>(
      find.descendant(of: summary, matching: find.byType(Image)),
    );
    expect((avatar.image as AssetImage).assetName, fixture.accountAvatar);
    await tapLive(tester, 'role-guide-edit-cast');
    await tapLive(tester, 'role-library-select-1');
    await tapLive(tester, 'role-library-create-project');
    expect(fixture.cast, isEmpty);
    expect(
      find.descendant(of: summary, matching: find.text('Account 101')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('role-guide-select-cast')), findsOneWidget);
    expect(
      fixture.requests.where(
        (request) => request.path == '/api_client/agent/v2/accounts/101',
      ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('account switch ignores a late account detail response', (
    tester,
  ) async {
    final pending = Completer<void>();
    final fixture = HomeCreationFixture()..waitForAccountDetail = pending;
    final container = await pumpLive(
      tester,
      fixture,
      route: '/role-guide?accountId=101',
    );
    final summary = find.byKey(const Key('role-guide-project-profile'));
    expect(
      find.descendant(of: summary, matching: find.byType(AppSkeletonBox)),
      findsNWidgets(2),
    );
    fixture.waitForAccountDetail = null;
    container.read(routerProvider(false)).go('/role-guide?accountId=202');
    await tester.pumpAndSettle();
    expect(find.text('Account 202'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Account 202'), findsOneWidget);
    expect(find.text('Account 101'), findsNothing);
    expect(
      fixture.requests.where(
        (request) => request.path == '/api_client/agent/v2/accounts/202',
      ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('account without an avatar uses the default project avatar', (
    tester,
  ) async {
    final fixture = HomeCreationFixture()..accountAvatar = '';
    await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
    final avatar = find.byKey(const Key('role-guide-account-avatar'));
    expect(
      tester
          .widget<AppSvgIcon>(
            find.descendant(of: avatar, matching: find.byType(AppSvgIcon)),
          )
          .assetName,
      'project_default_avatar',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account detail failure keeps the story and allows later refresh',
    (tester) async {
      final fixture = HomeCreationFixture()
        ..failAccountDetailOnce = true
        ..topics = [
          {'id': 'saved', 'title': 'Saved story', 'summary': 'Saved summary'},
        ];
      await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
      expect(
        find.byKey(const Key('role-guide-refresh-stories')),
        findsOneWidget,
      );
      await tapLive(tester, 'role-guide-refresh-stories');
      expect(find.text('Server story 1'), findsOneWidget);
      expect(find.text('Account 101'), findsOneWidget);
      expect(fixture.cast, [1]);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, locale, scale) in [
    (const Size(390, 844), const Locale('zh'), 1.0),
    (const Size(320, 640), const Locale('en'), 1.5),
  ]) {
    testWidgets(
      'topic selection and refresh remain available without custom input at $size',
      (tester) async {
        final fixture = HomeCreationFixture();
        await pumpLive(
          tester,
          fixture,
          size: size,
          locale: locale,
          scale: scale,
        );
        await tapLive(tester, 'role-guide-select-1');
        await tapLive(tester, 'role-guide-create-project');
        final entries = fixture.requests
            .where((request) => request.path.endsWith('/home/enter'))
            .length;
        expect(find.byKey(const Key('role-guide-custom-topic')), findsNothing);
        expect(find.text('自定义选题'), findsNothing);
        expect(find.text('Custom topic'), findsNothing);
        expect(
          find.byKey(const Key('role-guide-choose-story')),
          findsOneWidget,
        );
        await tapLive(tester, 'role-guide-refresh-stories');
        expect(find.text('Server story 2'), findsOneWidget);
        final recommendations = fixture.requests.where(
          (request) => request.path.endsWith('/topics'),
        );
        expect(
          recommendations.every(
            (request) => request.data['mode'] == 'recommend',
          ),
          isTrue,
        );
        await tapLive(tester, 'role-guide-choose-story');
        expect(find.byKey(const Key('role-guide-produce')), findsOneWidget);
        expect(
          fixture.requests.where(
            (request) => request.path.endsWith('/home/enter'),
          ),
          hasLength(entries),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('clearing and reselecting roles keeps the original account', (
    tester,
  ) async {
    final fixture = HomeCreationFixture();
    await pumpLive(tester, fixture);
    await tapLive(tester, 'role-guide-select-1');
    await tapLive(tester, 'role-guide-create-project');
    await tapLive(tester, 'role-guide-edit-cast');
    await tapLive(tester, 'role-library-select-1');
    await tapLive(tester, 'role-library-create-project');
    expect(fixture.cast, isEmpty);
    expect(find.byKey(const Key('role-guide-choose-story')), findsOneWidget);
    await tapLive(tester, 'role-guide-select-cast');
    await tapLive(tester, 'role-library-select-2');
    await tapLive(tester, 'role-library-create-project');
    expect(fixture.cast, [2]);
    expect(
      fixture.requests.where(
        (request) =>
            (request.data as Map?)?.containsKey('roleIds') == true &&
            request.path.endsWith('/home/enter'),
      ),
      hasLength(1),
    );
    expect(fixture.accountId, '101');
    expect(tester.takeException(), isNull);
  });

  for (final (locale, scale) in [
    (const Locale('zh'), 1.0),
    (const Locale('en'), 1.5),
  ]) {
    testWidgets('empty cast can be selected in place in $locale', (
      tester,
    ) async {
      final fixture = HomeCreationFixture()..cast = [];
      await pumpLive(
        tester,
        fixture,
        route: '/role-guide?accountId=101',
        size: const Size(320, 640),
        locale: locale,
        scale: scale,
        dark: true,
      );
      final panel = find.byKey(const Key('role-guide-panel'));
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(const Key('role-guide-select-cast')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('role-guide-rematch-stories')), findsNothing);
      await tapLive(tester, 'role-guide-select-cast');
      expect(find.byKey(const Key('role-guide-library-sheet')), findsOneWidget);
      expect(fixture.recommendationCount, 0);
      await tester.scrollUntilVisible(
        find.byKey(const Key('role-library-select-2')),
        80,
        scrollable: find.descendant(
          of: find.byKey(const Key('role-guide-library-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tapLive(tester, 'role-library-select-2');
      await tapLive(tester, 'role-library-create-project');
      expect(fixture.cast, [2]);
      expect(fixture.accountId, '101');
      expect(find.text('Server story 1'), findsOneWidget);
      expect(find.byKey(const Key('role-guide-library-sheet')), findsNothing);
      expect(find.byKey(const Key('role-guide-select-cast')), findsNothing);
      expect(find.byKey(const Key('role-guide-rematch-stories')), findsNothing);
      await tapLive(tester, 'role-guide-choose-story');
      expect(fixture.selected?['id'], 'topic-1');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'refreshing existing topics preserves cast and disables repeated requests',
    (tester) async {
      final fixture = HomeCreationFixture()
        ..topics = [
          {'id': 'saved', 'title': 'Saved story', 'summary': 'Saved summary'},
        ];
      await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
      final cast = find.byKey(const Key('role-guide-view-profiles'));
      final refresh = find.byKey(const Key('role-guide-refresh-stories'));
      expect(cast, findsOneWidget);
      expect(refresh, findsOneWidget);
      fixture.waitForTopics = Completer<void>();
      await tapLive(tester, 'role-guide-refresh-stories', running: true);
      expect(find.byKey(const Key('role-guide-loading')), findsOneWidget);
      expect(cast, findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.descendant(of: refresh, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('role-guide-edit-cast')), findsNothing);
      await tester.tap(
        find.byKey(const Key('role-guide-refresh-stories')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(
        fixture.requests.where((request) => request.path.endsWith('/topics')),
        hasLength(1),
      );
      fixture.waitForTopics!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Server story 1'), findsOneWidget);
      expect(find.byKey(const Key('role-guide-rematch-stories')), findsNothing);
      expect(fixture.cast, [1]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final cast in [
    <int>[],
    [1],
  ]) {
    testWidgets('empty topics disable refresh with cast $cast', (tester) async {
      final fixture = HomeCreationFixture()..cast = cast;
      await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
      final refresh = find.byKey(const Key('role-guide-refresh-stories'));
      expect(
        tester
            .widget<TextButton>(
              find.descendant(of: refresh, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('role-guide-rematch-stories')), findsNothing);
      expect(find.text('重新匹配选题'), findsNothing);
      await tapLive(tester, 'role-guide-refresh-stories');
      expect(fixture.recommendationCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('readonly empty plan disables changes with cast $cast', (
      tester,
    ) async {
      final fixture = HomeCreationFixture()
        ..cast = cast
        ..editable = false;
      await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
      if (cast.isEmpty) {
        final select = find.byKey(const Key('role-guide-select-cast'));
        expect(tester.widget<TextButton>(select).onPressed, isNull);
        await tester.tap(select);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('role-guide-library-sheet')), findsNothing);
      } else {
        expect(find.byKey(const Key('role-guide-edit-cast')), findsNothing);
      }
      for (final key in ['role-guide-refresh-stories']) {
        final action = find.byKey(Key(key));
        expect(
          tester
              .widget<TextButton>(
                find.descendant(of: action, matching: find.byType(TextButton)),
              )
              .onPressed,
          isNull,
        );
        await tapLive(tester, key);
      }
      expect(fixture.recommendationCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'completed frozen creation can continue without resending old inputs',
    (tester) async {
      final fixture = HomeCreationFixture()
        ..task = HomeCreationFixture().taskValue('completed', lock: 'released');
      await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
      await tapLive(tester, 'role-guide-generation-action');
      final entries = fixture.requests
          .where((request) => request.path.endsWith('/home/enter'))
          .toList();
      expect(entries.last.data['newCreation'], isTrue);
      expect(entries.last.data.containsKey('sourceCreationId'), isFalse);
      expect(entries.last.data.containsKey('sessionId'), isFalse);
      expect(find.text('Server story 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (entry, size, locale, scale) in [
    (
      'role-guide-project-profile',
      const Size(390, 844),
      const Locale('zh'),
      1.0,
    ),
    ('role-guide-view-profiles', const Size(320, 640), const Locale('en'), 1.0),
    (
      'role-guide-project-profile',
      const Size(320, 844),
      const Locale('en'),
      1.5,
    ),
  ]) {
    testWidgets(
      'confirmed creation role edits save locally through $entry at $size scale $scale',
      (tester) async {
        final fixture = HomeCreationFixture()..clearTopicsOnRoleChange = false;
        fixture.creationProfiles[1] = {
          'title': 'Character 1',
          'description': 'Profile 1',
          'expressionStyle': 'Original style',
          'targetAudience': 'Students',
          'contentTags': ['School'],
          'profileData': {
            'appearance': {
              'label': 'Appearance',
              'value': 'Original appearance',
            },
          },
        };
        await pumpLive(
          tester,
          fixture,
          size: size,
          locale: locale,
          scale: scale,
          dark: scale > 1,
        );
        await tapLive(tester, 'role-guide-select-1');
        await tapLive(tester, 'role-guide-create-project');
        await tapLive(tester, 'role-guide-choose-story');
        expect(fixture.selected!['id'], 'topic-1');
        await tapLive(tester, 'role-guide-back');
        final libraryReads = fixture.requests
            .where((request) => request.path.contains('/roles/'))
            .length;
        await tapLive(tester, entry);
        final preview = find.byKey(const Key('role-guide-profile-sheet'));
        expect(preview, findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byKey(const Key('home-role-profile-sheet')), findsNothing);
        final route = ModalRoute.of(tester.element(preview));
        await tapLive(tester, 'role-profile-edit-creation');
        final sheet = find.byKey(const Key('role-creation-profile-form'));
        expect(sheet, findsOneWidget);
        expect(preview, findsOneWidget);
        expect(ModalRoute.of(tester.element(preview)), same(route));
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        expect(find.byKey(const ValueKey(('1', 'title'))), findsNothing);
        expect(find.byKey(const ValueKey(('1', 'description'))), findsNothing);
        final style = find.byKey(const ValueKey(('1', 'expressionStyle')));
        await tester.enterText(style, '');
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('home-role-edit-save')),
              )
              .onPressed,
          isNull,
        );
        expect(
          fixture.requests.where(
            (request) => request.path.endsWith('/role-versions'),
          ),
          isEmpty,
        );
        await tester.enterText(style, 'This creation only');
        fixture.failRoleSaveOnce = true;
        await tapLive(tester, 'home-role-edit-save');
        expect(sheet, findsOneWidget);
        expect(
          tester.widget<TextFormField>(style).controller!.text,
          'This creation only',
        );
        final l10n = locale.languageCode == 'zh'
            ? '角色档案保存失败，请稍后重试'
            : 'Could not save the role profile. Try again.';
        expect(find.text(l10n), findsOneWidget);
        expect(fixture.recommendationCount, 1);
        await tapLive(tester, 'home-role-edit-save');
        expect(sheet, findsNothing);
        expect(preview, findsOneWidget);
        expect(
          find.descendant(
            of: preview,
            matching: find.text('This creation only'),
          ),
          findsOneWidget,
        );
        expect(
          fixture.creationProfiles[1]!['expressionStyle'],
          'This creation only',
        );
        expect(fixture.creationProfiles[1]!['title'], 'Character 1');
        expect(fixture.creationProfiles[1]!['description'], 'Profile 1');
        expect(fixture.selected, isNull);
        expect(fixture.recommendationCount, 2);
        expect(find.text('Server story 1'), findsNothing);
        expect(find.text('Server story 2'), findsOneWidget);
        expect(fixture.role(1)['title'], 'Character 1');
        expect(
          fixture.requests
              .where((request) => request.path.contains('/roles/'))
              .length,
          libraryReads,
        );
        await tapLive(tester, 'role-profile-edit-creation');
        expect(
          tester.widget<TextFormField>(style).controller!.text,
          'This creation only',
        );
        await tester.enterText(style, 'Discard this change');
        await tapLive(tester, 'home-role-edit-cancel');
        expect(preview, findsOneWidget);
        expect(sheet, findsNothing);
        expect(
          fixture.creationProfiles[1]!['expressionStyle'],
          'This creation only',
        );
        await tapLive(tester, 'role-profile-edit-creation');
        await tester.enterText(style, 'Discard on back');
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const Key('home-role-edit-save'))).bottom,
          lessThanOrEqualTo(size.height - 240),
        );
        await tester.binding.handlePopRoute();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(preview, findsOneWidget);
        expect(sheet, findsNothing);
        expect(ModalRoute.of(tester.element(preview)), same(route));
        expect(
          fixture.creationProfiles[1]!['expressionStyle'],
          'This creation only',
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('topic loading keeps the cast above the spinner at $size', (
      tester,
    ) async {
      final fixture = HomeCreationFixture()..waitForTopics = Completer<void>();
      await pumpLive(tester, fixture, size: size);
      await tapLive(tester, 'role-guide-select-1');
      await tapLive(tester, 'role-guide-create-project', running: true);
      final cast = find.byKey(const Key('role-guide-view-profiles'));
      final loading = find.byKey(const Key('role-guide-loading'));
      Future<void> expectLoading() async {
        await Scrollable.ensureVisible(
          tester.element(loading),
          alignment: 1,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        await tester.pump();
        expect(cast, findsOneWidget);
        expect(
          find.descendant(of: cast, matching: find.text('Character 1')),
          findsOneWidget,
        );
        expect(loading, findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('role-guide-panel')),
            matching: loading,
          ),
          findsOneWidget,
        );
        expect(
          tester.getRect(loading).top,
          greaterThan(tester.getRect(cast).bottom),
        );
        expect(
          tester.getRect(loading).bottom,
          lessThan(
            tester
                .getRect(find.byKey(const Key('role-guide-choose-story')))
                .top,
          ),
        );
      }

      await expectLoading();
      fixture.waitForTopics!.complete();
      await tester.pumpAndSettle();
      expect(loading, findsNothing);
      expect(find.text('Server story 1'), findsOneWidget);

      fixture.waitForTopics = Completer<void>();
      await tapLive(tester, 'role-guide-refresh-stories', running: true);
      await expectLoading();
      expect(find.text('Server story 1'), findsNothing);
      fixture.waitForTopics!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Server story 2'), findsOneWidget);
      expect(cast, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fromLibrary in [false, true]) {
    testWidgets(
      'updating cast refreshes retained topics from library=$fromLibrary',
      (tester) async {
        final fixture = HomeCreationFixture()..clearTopicsOnRoleChange = false;
        await pumpLive(tester, fixture);
        await tapLive(tester, 'role-guide-select-1');
        await tapLive(tester, 'role-guide-create-project');
        expect(find.text('Server story 1'), findsOneWidget);
        if (fromLibrary) {
          await tapLive(tester, 'role-guide-edit-cast');
          await tapLive(tester, 'role-library-select-1');
          await tapLive(tester, 'role-library-select-2');
          await tapLive(tester, 'role-library-create-project');
        } else {
          await tapLive(tester, 'role-guide-back');
          await tapLive(tester, 'role-guide-select-1');
          await tapLive(tester, 'role-guide-select-2');
          await tapLive(tester, 'role-guide-create-project');
        }
        expect(fixture.cast, [2]);
        expect(fixture.recommendationCount, 2);
        expect(find.text('Server story 1'), findsNothing);
        expect(find.text('Server story 2'), findsOneWidget);
        final requests = fixture.requests
            .where(
              (request) =>
                  request.path.endsWith('/cast') ||
                  request.path.endsWith('/topics'),
            )
            .toList();
        expect(requests, hasLength(3));
        expect(requests[1].path, endsWith('/cast'));
        expect(requests[2].path, endsWith('/topics'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('replacing the cast rematches topics and lets failures retry', (
    tester,
  ) async {
    final fixture = HomeCreationFixture();
    await pumpLive(tester, fixture);
    await tapLive(tester, 'role-guide-select-1');
    await tapLive(tester, 'role-guide-create-project');
    await tapLive(tester, 'role-guide-choose-story');
    await tapLive(tester, 'role-guide-back');
    await tapLive(tester, 'role-guide-edit-cast');
    await tapLive(tester, 'role-library-select-1');
    await tapLive(tester, 'role-library-select-2');
    fixture.failTopicsOnce = true;
    await tapLive(tester, 'role-library-create-project');
    expect(fixture.cast, [2]);
    expect(fixture.selected, isNull);
    expect(find.byKey(const Key('role-guide-library-sheet')), findsNothing);
    final cast = find.byKey(const Key('role-guide-view-profiles'));
    expect(
      find.descendant(of: cast, matching: find.text('Character 2')),
      findsOneWidget,
    );
    expect(find.text('Server story 1'), findsNothing);
    expect(find.byKey(const Key('role-guide-rematch-stories')), findsNothing);
    await tapLive(tester, 'role-guide-edit-cast');
    await tapLive(tester, 'role-library-create-project');
    expect(find.text('Server story 3'), findsOneWidget);
    expect(fixture.recommendationCount, 3);
    final replacements = fixture.requests.where(
      (request) => request.path.endsWith('/cast'),
    );
    expect(replacements, hasLength(2));
    await tapLive(tester, 'role-guide-choose-story');
    expect(fixture.selected!['id'], 'topic-3');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live flow uses server stories, pricing and tasks; pause stops polling',
    (tester) async {
      final fixture = HomeCreationFixture();
      final container = await pumpLive(tester, fixture);
      await tapLive(tester, 'role-guide-select-1');
      await tapLive(tester, 'role-guide-create-project');
      expect(find.text('Server story 1'), findsOneWidget);
      expect(
        container
            .read(routerProvider(false))
            .state
            .uri
            .queryParameters['accountId'],
        '101',
      );
      await tapLive(tester, 'role-guide-choose-story');
      expect(fixture.selected!['id'], 'topic-1');
      await tapLive(tester, 'role-guide-configure');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Server video model'), findsOneWidget);
      expect(find.text('图片偏好'), findsNothing);
      expect(find.textContaining('42'), findsOneWidget);
      await tapLive(tester, 'home-config-confirm');
      expect(
        fixture.requests.where(
          (request) => request.path.endsWith('/session-media-preferences'),
        ),
        isEmpty,
      );
      final entries = fixture.requests
          .where((request) => request.path.endsWith('/home/enter'))
          .length;
      fixture.cast = [2];
      await tapLive(tester, 'role-guide-produce', running: true);
      expect(fixture.task!['state'], 'queued');
      final generation = fixture.requests.singleWhere(
        (request) => request.path.endsWith('/generate'),
      );
      expect(
        generation.path,
        '/api_agent/v2/sessions/11111111-1111-4111-8111-111111111111/generate',
      );
      expect(
        generation.data.keys,
        unorderedEquals(['clientRequestId', 'config']),
      );
      expect(find.text('Account 101'), findsOneWidget);
      expect(
        fixture.requests.where(
          (request) => request.path.endsWith('/home/enter'),
        ),
        hasLength(entries),
      );
      expect(find.textContaining('交互预览'), findsNothing);
      await tapLive(tester, 'role-guide-pause', running: true);
      expect(fixture.task!['state'], 'paused');
      final polls = fixture.requests
          .where(
            (request) =>
                request.method == 'GET' &&
                request.path.contains('/home-tasks/'),
          )
          .length;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(
        fixture.requests
            .where(
              (request) =>
                  request.method == 'GET' &&
                  request.path.contains('/home-tasks/'),
            )
            .length,
        polls,
      );
      await tapLive(tester, 'role-guide-generation-action', running: true);
      expect(fixture.task!['state'], 'running');
      fixture.task = fixture.taskValue(
        'completed',
        version: 8,
        lock: 'released',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('生成成功！'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'canceling releases the creation for another generation with the same config',
    (tester) async {
      final fixture = HomeCreationFixture()
        ..selected = {
          'id': 'saved',
          'title': 'Saved story',
          'summary': 'Saved body',
        };
      await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
      await tapLive(tester, 'role-guide-configure');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tapLive(tester, 'home-config-confirm');
      await tapLive(tester, 'role-guide-produce', running: true);
      await tapLive(tester, 'role-guide-generation-action', running: true);
      await tapLive(tester, 'role-guide-confirm-stop', running: true);
      expect(fixture.task!['state'], 'canceled');
      final cancellation = fixture.requests.firstWhere(
        (request) => request.path.endsWith('/control'),
      );
      expect(
        cancellation.data.keys,
        unorderedEquals(['clientRequestId', 'action']),
      );
      await tapLive(tester, 'role-guide-back');
      await tapLive(tester, 'role-guide-produce', running: true);
      final generations = fixture.requests
          .where((request) => request.path.endsWith('/generate'))
          .toList();
      expect(generations, hasLength(2));
      expect(generations.last.data['config'], generations.first.data['config']);
      expect(
        generations.last.data['clientRequestId'],
        isNot(generations.first.data['clientRequestId']),
      );
      expect(fixture.task!['state'], 'queued');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'switch project pages accounts and reads home on the topic step',
    (tester) async {
      final fixture = HomeCreationFixture();
      final container = await pumpLive(tester, fixture);
      await tapLive(tester, 'role-guide-switch-project');
      expect(
        fixture.requests.where((request) => request.path.endsWith('/accounts')),
        hasLength(1),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('role-project-select-202')),
        500,
        scrollable: find.descendant(
          of: find.byKey(const Key('role-project-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tapLive(tester, 'role-project-select-202');
      await tapLive(tester, 'role-project-confirm');
      expect(find.byType(RoleGuidePage), findsOneWidget);
      expect(find.text('Server story 1'), findsOneWidget);
      expect(find.byKey(const Key('role-guide-choose-story')), findsOneWidget);
      expect(fixture.accountId, '202');
      final accounts = fixture.requests
          .where((request) => request.path.endsWith('/accounts'))
          .toList();
      expect(accounts.map((request) => request.queryParameters), [
        {'page': 1, 'pageSize': 20},
        {'page': 2, 'pageSize': 20},
      ]);
      final entries = fixture.requests
          .where((request) => request.path.endsWith('/home/enter'))
          .toList();
      expect(entries, hasLength(1));
      expect(entries.single.data['accountId'], '202');
      expect(
        fixture.requests.indexOf(entries.single),
        lessThan(
          fixture.requests.indexWhere(
            (request) => request.path.endsWith('/topics'),
          ),
        ),
      );
      expect(
        fixture.requests.any(
          (request) =>
              request.method == 'POST' && request.path.endsWith('/sessions'),
        ),
        isFalse,
      );
      expect(
        container
            .read(routerProvider(false))
            .state
            .uri
            .queryParameters['accountId'],
        '202',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switch project enters the topic step while home loads', (
    tester,
  ) async {
    final fixture = HomeCreationFixture()..waitForEntry = Completer<void>();
    addTearDown(() {
      if (!fixture.waitForEntry!.isCompleted) {
        fixture.waitForEntry!.complete();
      }
    });
    await pumpLive(tester, fixture);
    await tapLive(tester, 'role-guide-select-1');
    await tapLive(tester, 'role-guide-switch-project');
    await tapLive(tester, 'role-project-select-101');
    await tapLive(tester, 'role-project-confirm', running: true);
    expect(find.byKey(const Key('role-guide-choose-story')), findsOneWidget);
    expect(find.byKey(const Key('role-guide-loading')), findsOneWidget);
    expect(find.byKey(const Key('role-guide-create-project')), findsNothing);
    expect(
      fixture.requests.any((request) => request.path.endsWith('/topics')),
      isFalse,
    );
    fixture.waitForEntry!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Server story 1'), findsOneWidget);
    await tapLive(tester, 'role-guide-choose-story');
    expect(find.byKey(const Key('role-guide-produce')), findsOneWidget);
    expect(
      fixture.requests.where((request) => request.path.endsWith('/home/enter')),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  for (final editable in [true, false]) {
    for (final (state, expectedAction, previousAction) in [
      ('story', 'role-guide-choose-story', 'role-guide-create-project'),
      ('empty-cast', 'role-guide-choose-story', 'role-guide-create-project'),
      ('production', 'role-guide-produce', 'role-guide-choose-story'),
      ('generation', 'role-guide-generation-action', 'role-guide-produce'),
    ]) {
      testWidgets(
        'account snapshot restores $state and editable=$editable controls back',
        (tester) async {
          final fixture = HomeCreationFixture()..editable = editable;
          if (state == 'empty-cast') {
            fixture.cast = [];
          } else {
            fixture.topics = [
              {
                'id': 'saved',
                'title': 'Saved story',
                'summary': 'Saved summary',
              },
            ];
          }
          if (state == 'production' || state == 'generation') {
            fixture.selected = fixture.topics.single;
          }
          if (state == 'generation') {
            fixture.task = fixture.taskValue('paused');
          }
          await pumpLive(tester, fixture);
          await tapLive(tester, 'role-guide-switch-project');
          await tapLive(tester, 'role-project-select-101');
          await tapLive(tester, 'role-project-confirm');
          expect(find.byKey(Key(expectedAction)), findsOneWidget);
          expect(
            fixture.requests.where(
              (request) => request.path.endsWith('/home/enter'),
            ),
            hasLength(1),
          );
          expect(
            fixture.requests.any((request) => request.path.endsWith('/topics')),
            isFalse,
          );
          final back = find.byKey(const Key('role-guide-back'));
          expect(
            tester.widget<IconButton>(back).onPressed,
            editable ? isNotNull : isNull,
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            find.byKey(Key(editable ? previousAction : expectedAction)),
            findsOneWidget,
          );
          if (editable) {
            // Restore the snapshot to exercise the app-bar button separately.
            final router = ProviderScope.containerOf(
              tester.element(find.byType(RoleGuidePage)),
            ).read(routerProvider(false));
            router.go('/role-guide');
            await tester.pumpAndSettle();
            await tapLive(tester, 'role-guide-switch-project');
            await tapLive(tester, 'role-project-select-101');
            await tapLive(tester, 'role-project-confirm');
            await tester.tap(back);
            await tester.pumpAndSettle();
            expect(find.byKey(Key(previousAction)), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final (cast, editable, enabled) in [
    (<int>[], true, false),
    ([1], true, true),
    ([1], false, false),
  ]) {
    testWidgets(
      'topic confirmation with ${cast.length} characters and editable=$editable',
      (tester) async {
        final fixture = HomeCreationFixture()
          ..cast = cast
          ..editable = editable
          ..topics = [
            {'id': 'saved', 'title': 'Saved story', 'summary': 'Saved summary'},
          ];
        await pumpLive(tester, fixture, route: '/role-guide?accountId=101');
        final confirm = find.byKey(const Key('role-guide-choose-story'));
        final button = tester.widget<TextButton>(
          find.descendant(of: confirm, matching: find.byType(TextButton)),
        );
        expect(button.onPressed, enabled ? isNotNull : isNull);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(
          fixture.requests.where((request) => request.path.endsWith('/topic')),
          hasLength(enabled ? 1 : 0),
        );
        expect(
          find.byKey(
            Key(enabled ? 'role-guide-produce' : 'role-guide-choose-story'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'story request failure keeps cast and disables refresh for empty topics',
    (tester) async {
      final fixture = HomeCreationFixture()..failTopicsOnce = true;
      await pumpLive(tester, fixture);
      await tapLive(tester, 'role-guide-select-1');
      await tapLive(tester, 'role-guide-create-project');
      expect(find.text('创作请求失败，请重试'), findsNothing);
      expect(find.text('暂无推荐故事'), findsOneWidget);
      final panel = find.byKey(const Key('role-guide-panel'));
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(const Key('role-guide-request-retry')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: panel, matching: find.text('选题请求失败')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(const Key('role-guide-rematch-stories')),
        ),
        findsNothing,
      );
      expect(find.text('都不满意，换一批'), findsOneWidget);
      final refresh = find.byKey(const Key('role-guide-refresh-stories'));
      expect(
        tester
            .widget<TextButton>(
              find.descendant(of: refresh, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNull,
      );
      await tapLive(tester, 'role-guide-refresh-stories');
      final requests = fixture.requests
          .where((request) => request.path.endsWith('/topics'))
          .toList();
      expect(requests.length, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('entry retry keeps request ID; logout discards a late response', (
    tester,
  ) async {
    final fixture = HomeCreationFixture()..failEntryOnce = true;
    final container = await pumpLive(tester, fixture);
    await tapLive(tester, 'role-guide-select-1');
    await tapLive(tester, 'role-guide-create-project');
    expect(find.byKey(const Key('role-guide-request-retry')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('role-guide-request-retry')),
    );
    await tester.pumpAndSettle();
    fixture.waitForEntry = Completer<void>();
    await tester.tap(find.byKey(const Key('role-guide-request-retry')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('role-guide-loading')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    final entries = fixture.requests
        .where((request) => request.path.endsWith('/home/enter'))
        .toList();
    expect(entries.length, 2);
    expect(entries.first.data, entries.last.data);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'other', name: 'Other', email: ''));
    fixture.waitForEntry!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-guide-loading')), findsNothing);
    expect(find.text('Server story 1'), findsNothing);
    expect(find.byKey(const Key('role-guide-create-project')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets('generated video replaces the result placeholder at $size', (
      tester,
    ) async {
      final original = VideoPlayerPlatform.instance;
      final platform = FakeVideoPlayer()..videoSize = const Size(1080, 1920);
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = original);
      final fixture = HomeCreationFixture();
      fixture.task = fixture.taskValue('completed', lock: 'released');
      fixture.task!['steps'] = [
        {
          'key': 'video',
          'state': 'completed',
          'output': {
            'kind': 'video',
            'title': 'Video result',
            'body': 'Video complete',
            'mediaId': '901',
          },
        },
      ];
      await pumpLive(
        tester,
        fixture,
        size: size,
        locale: const Locale('en'),
        route: '/role-guide?accountId=101&sessionId=saved-session',
      );
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(
        platform.sources.single.uri,
        'http://business.test/generated/video.mp4',
      );
      expect(platform.playing, isFalse);
      await tapLive(tester, 'role-video-play');
      expect(platform.playing, isTrue);
      final slider = tester.widget<Slider>(
        find.byKey(const Key('role-video-seek')),
      );
      slider.onChanged!(15);
      slider.onChangeEnd!(15);
      await tester.pumpAndSettle();
      expect(platform.positions[1], const Duration(seconds: 15));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(platform.playing, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final bounds = tester.getRect(find.byType(VideoPlayer));
      expect(bounds.width, lessThanOrEqualTo(size.width));
      expect(bounds.height / bounds.width, closeTo(1920 / 1080, .01));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(platform.disposed, [1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'unified storyboard prompt expands with a rounded hit area at $size',
      (tester) async {
        final fixture = HomeCreationFixture();
        fixture.task = fixture.taskValue('completed', lock: 'released');
        fixture.task!['steps'] = [
          {
            'key': 'storyboard',
            'state': 'completed',
            'output': {
              'title': 'Storyboard',
              'body': jsonEncode({
                'shots': [
                  {
                    'key': 'shot1',
                    'duration': 3,
                    'description': 'Wide shot\n**Action:** enters the room',
                  },
                  {'duration': 1.5, 'description': 'Close-up'},
                ],
                'modelPrompt': 'Keep the camera steady.',
              }),
            },
          },
        ];
        await pumpLive(
          tester,
          fixture,
          size: size,
          locale: const Locale('en'),
          route: '/role-guide?accountId=101&sessionId=saved-session',
        );
        expect(find.text('Storyboard video prompt'), findsOneWidget);
        expect(find.textContaining('Wide shot'), findsNothing);
        expect(find.text('Video model prompt'), findsNothing);
        expect(
          find.text('Keep the camera steady.', findRichText: true),
          findsWidgets,
        );
        expect(find.textContaining('"shots"'), findsNothing);
        final artifact = find.byKey(
          const Key('role-guide-artifact-Storyboard'),
        );
        final header = find.descendant(
          of: artifact,
          matching: find.byType(ListTile),
        );
        final ink = tester.widget<InkWell>(
          find.descendant(of: header, matching: find.byType(InkWell)),
        );
        expect(
          (ink.customBorder! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(8),
        );
        await tester.ensureVisible(header);
        await tester.pumpAndSettle();
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(find.text('Keep the camera steady.'), findsNothing);
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(find.text('Keep the camera steady.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('saved live story fits English layout at $size', (
      tester,
    ) async {
      final fixture = HomeCreationFixture()
        ..selected = {
          'id': 'saved',
          'title': 'Saved story',
          'summary': '## Story outline\n\nA **bold** story\n\n- First beat',
        };
      await pumpLive(
        tester,
        fixture,
        size: size,
        locale: const Locale('en'),
        route: '/role-guide?accountId=101&sessionId=saved-session',
      );
      expect(find.text('Saved story'), findsOneWidget);
      expect(find.text('Story outline', findRichText: true), findsWidgets);
      expect(find.text('A bold story', findRichText: true), findsWidgets);
      expect(find.text('First beat', findRichText: true), findsWidgets);
      expect(find.textContaining('**'), findsNothing);
      await tapLive(tester, 'role-guide-configure');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Server video model'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
