import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/data/demo_website_character_catalog.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<DemoRepository> _pumpSettings(
  WidgetTester tester, {
  DemoRepository? repository,
  String sessionId = 'inspiration',
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (repository == null) SharedPreferences.setMockInitialValues({});
  final resolvedRepository =
      repository ??
      (DemoRepository(PreferencesStorage(await SharedPreferences.getInstance()))
        ..restore());
  addTearDown(resolvedRepository.dispose);
  await tester.pumpWidget(
    ToastificationWrapper(
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DemoSettingsPage(
          repository: resolvedRepository,
          sessionId: sessionId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return resolvedRepository;
}

class _CatalogRepository extends DemoRepository {
  _CatalogRepository(super.storage);

  final List<String?> requestedSessionIds = [];

  @override
  Future<DemoCapabilityCatalog> loadCapabilityCatalog({
    String? sessionId,
  }) async {
    requestedSessionIds.add(sessionId);
    if (sessionId != null && session(sessionId).workMode == 'manual') {
      return const DemoCapabilityCatalog(
        tools: [
          DemoRuntimeCapability(
            id: 'web_search',
            name: 'web_search',
            source: 'dsh',
            available: true,
          ),
          DemoRuntimeCapability(
            id: 'media_generate',
            name: 'media_generate',
            source: 'dsh',
            bound: true,
            granted: false,
          ),
        ],
      );
    }
    return DemoCapabilityCatalog(
      tools:
          const [
                'web_search',
                'web_fetch',
                'media_models',
                'media_preflight',
                'media_generate',
                'media_status',
                'media_jobs',
                'media_vision',
              ]
              .map(
                (id) => DemoRuntimeCapability(
                  id: id,
                  name: id,
                  description: 'DSH tool',
                  source: 'dsh',
                  available: true,
                ),
              )
              .toList(),
    );
  }
}

class _FailingCatalogRepository extends DemoRepository {
  _FailingCatalogRepository(super.storage);

  @override
  Future<DemoCapabilityCatalog> loadCapabilityCatalog({
    String? sessionId,
  }) async => throw StateError('catalog unavailable');
}

class _RefreshFailingCatalogRepository extends DemoRepository {
  _RefreshFailingCatalogRepository(super.storage);

  final List<String?> requestedSessionIds = [];

  @override
  Future<DemoCapabilityCatalog> loadCapabilityCatalog({
    String? sessionId,
  }) async {
    requestedSessionIds.add(sessionId);
    if (requestedSessionIds.length > 1) {
      throw StateError('refresh unavailable');
    }
    return const DemoCapabilityCatalog(
      tools: [
        DemoRuntimeCapability(
          id: 'web_search',
          name: 'web_search',
          source: 'dsh',
          available: true,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('settings use the single assistant given name consistently', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    final original = repository.session('alice');
    await repository.updateSession(
      original.id,
      (session) => session.copyWith(
        title: '新建会话',
        memberNames: {...session.memberNames, 'popi': '哈哈'},
      ),
    );
    await _pumpSettings(tester, repository: repository, sessionId: 'alice');

    expect(find.text('哈哈'), findsOneWidget);
    expect(find.text('新建会话'), findsNothing);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-edit-member-popi')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('demo-member-name')))
          .controller!
          .text,
      '哈哈',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings use the compact 375px reference hierarchy', (
    tester,
  ) async {
    await _pumpSettings(tester);

    final avatar = find.byType(DemoAvatar).first;
    expect(tester.getSize(avatar), const Size(60, 60));
    expect(find.text('关联角色'), findsOneWidget);
    expect(find.text('内容方向'), findsOneWidget);
    expect(find.text('目标受众'), findsOneWidget);
    expect(find.text('账号定位'), findsOneWidget);
    expect(find.textContaining('@'), findsOneWidget);
    expect(tester.getTopLeft(find.text('关联角色')).dx, closeTo(32, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'adding members is disabled while an existing member is editable',
    (tester) async {
      final repository = await _pumpSettings(tester);
      await tester.tap(find.text('能力'));
      await tester.pumpAndSettle();
      final add = find.descendant(
        of: find.byKey(const Key('demo-add-members')),
        matching: find.byType(TextButton),
      );
      final addButton = tester.widget<TextButton>(add);
      final addContext = tester.element(add);
      expect(addButton.onPressed, isNull);
      expect(
        addButton.style?.backgroundColor?.resolve({WidgetState.disabled}),
        Theme.of(addContext).colorScheme.surfaceContainerHighest,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Tooltip && widget.message == '当前仅支持选择一名助理',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('demo-edit-member-popi')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('demo-edit-member-scroll')), findsOneWidget);
      expect(repository.session('inspiration').members, [
        'popi',
        'writer',
        'director',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('role order survives scrolling and a sixth role is refused', (
    tester,
  ) async {
    final repository = await _pumpSettings(tester);
    await tester.tap(find.byKey(const Key('demo-settings-roles')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('demo-role-option-hua')));
    Navigator.of(tester.element(find.text('关联角色').last)).pop();
    await tester.pumpAndSettle();
    expect(repository.session('inspiration').roles, ['alice', 'er', 'dou']);

    await tester.tap(find.byKey(const Key('demo-settings-roles')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('demo-role-option-hua')));
    await tester.tap(find.byKey(const ValueKey('demo-role-option-qiqi')));
    await tester.drag(
      find.byKey(const ValueKey('demo-role-grid-0')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('demo-role-option-fish')),
    );
    await tester.tap(find.byKey(const ValueKey('demo-role-option-fish')));
    await tester.tap(find.byKey(const Key('demo-roles-confirm')));
    await tester.pumpAndSettle();

    expect(repository.session('inspiration').roles, [
      'alice',
      'er',
      'dou',
      'hua',
      'qiqi',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'website character association saves its complete source profile',
    (tester) async {
      final repository = await _pumpSettings(tester);
      const roleId = 'popi-character-1058';
      expect(repository.session('inspiration').roles, isNot(contains(roleId)));

      await tester.tap(find.byKey(const Key('demo-settings-roles')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('demo-role-profile-link-$roleId')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('性格：活泼开朗'), findsOneWidget);
      expect(find.textContaining('不将多视图当作多个人物'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('demo-role-option-$roleId')));
      await tester.tap(find.byKey(const Key('demo-roles-confirm')));
      await tester.pumpAndSettle();

      final saved = repository.session('inspiration');
      expect(saved.roles, contains(roleId));
      expect(
        saved.roleProfiles[roleId]?.toJson(),
        DemoWebsiteCharacterCatalog.profile(roleId)?.toJson(),
      );
      expect(saved.roleProfiles[roleId]?.isReady, isTrue);
      expect(saved.members, contains('popi'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('existing website character edits override catalog defaults', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    const roleId = 'popi-character-655';
    const edited = DemoRoleProfile(
      name: '我的康欣',
      instructions: '用户自定义设定',
      revision: 'user-revision',
      referenceImageUrls: ['https://example.test/user-kangxin.png'],
    );
    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(
        roles: [...session.roles, roleId],
        roleProfiles: {...session.roleProfiles, roleId: edited},
      ),
    );
    await _pumpSettings(tester, repository: repository);

    await tester.tap(find.byKey(const Key('demo-settings-roles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-roles-confirm')));
    await tester.pumpAndSettle();

    expect(
      repository.session('inspiration').roleProfiles[roleId]?.toJson(),
      edited.toJson(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DSH capability catalog is read only and tools default available',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _CatalogRepository(
        PreferencesStorage(await SharedPreferences.getInstance()),
      )..restore();
      await _pumpSettings(tester, repository: repository);
      expect(repository.requestedSessionIds, ['inspiration']);
      await tester.tap(find.text('能力'));
      await tester.pumpAndSettle();

      final tools = find.byKey(const ValueKey('demo-dsh-tools'));
      final skills = find.byKey(const ValueKey('demo-dsh-skills'));
      final mcp = find.byKey(const ValueKey('demo-dsh-mcp'));
      expect(tools, findsOneWidget);
      expect(skills, findsOneWidget);
      expect(mcp, findsOneWidget);
      expect(
        find.descendant(of: tools, matching: find.byIcon(Icons.check_circle)),
        findsNWidgets(8),
      );
      expect(
        find.descendant(of: skills, matching: find.text('尚未接入')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: mcp, matching: find.text('尚未接入')),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.text('添加能力'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offline catalog states that DSH bindings are not connected', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();

    expect(find.text('尚未接入'), findsNWidgets(3));
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog request failure only shows toast and keeps settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FailingCatalogRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    await _pumpSettings(tester, repository: repository);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();

    expect(find.text('本地保存失败，请再次操作'), findsOneWidget);
    expect(find.text('尚未接入'), findsNothing);
    expect(find.byKey(const ValueKey('demo-dsh-tools')), findsNothing);
    expect(find.byKey(const ValueKey('demo-member-popi')), findsOneWidget);
    expect(find.byKey(const Key('demo-add-members')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('failed grant refresh retains names with unconfirmed status', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _RefreshFailingCatalogRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    await _pumpSettings(tester, repository: repository);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    expect(find.text('本会话已启用'), findsOneWidget);

    final settingsScroll = find
        .descendant(
          of: find.byKey(const PageStorageKey('demo-settings-skills')),
          matching: find.byType(Scrollable),
        )
        .first;
    final workMode = find.byKey(const Key('demo-work-mode'));
    await tester.scrollUntilVisible(workMode, 240, scrollable: settingsScroll);
    await tester.tap(workMode);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-work-mode-manual')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-active-member-writer')));
    await tester.tap(find.byKey(const Key('demo-work-mode-confirm')));
    await tester.pumpAndSettle();

    final tools = find.byKey(const ValueKey('demo-dsh-tools'));
    expect(repository.requestedSessionIds, ['inspiration', 'inspiration']);
    expect(
      find.byKey(const ValueKey('demo-dsh-tools-web_search')),
      findsOneWidget,
    );
    expect(find.text('本会话已启用'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('demo-dsh-tools-web_search')),
        matching: find.text('状态待确认'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tools, matching: find.byIcon(Icons.check_circle)),
      findsNothing,
    );
    expect(
      find.descendant(of: tools, matching: find.byIcon(Icons.help_outline)),
      findsOneWidget,
    );
    expect(find.text('本地保存失败，请再次操作'), findsOneWidget);
    await tester.pump();
    expect(repository.requestedSessionIds, hasLength(2));
    expect(find.text('本地保存失败，请再次操作'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('external permission changes refresh without chat-style churn', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _CatalogRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    await _pumpSettings(tester, repository: repository);
    expect(repository.requestedSessionIds, ['inspiration']);

    await repository.updateSession(
      'inspiration',
      (session) =>
          session.copyWith(workMode: 'manual', activeMemberId: 'writer'),
    );
    await tester.pumpAndSettle();
    expect(repository.requestedSessionIds, ['inspiration', 'inspiration']);

    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(direction: '新的内容方向'),
    );
    await tester.pumpAndSettle();
    expect(repository.requestedSessionIds, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('role reference selection removal save and cancel are isolated', (
    tester,
  ) async {
    final repository = await _pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('demo-role-profile-alice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('demo-add-reference-image')),
    );
    await tester.tap(find.byKey(const Key('demo-add-reference-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-reference-asset-scene1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('demo-remove-reference-scene1')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      repository
              .session('inspiration')
              .roleProfiles['alice']
              ?.referenceAssetIds ??
          const [],
      isEmpty,
    );

    await tester.tap(find.byKey(const ValueKey('demo-role-profile-alice')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('demo-add-reference-image')),
    );
    await tester.tap(find.byKey(const Key('demo-add-reference-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-reference-asset-scene1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('demo-remove-reference-scene1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-add-reference-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-reference-asset-scene2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('demo-role-profile-confirm')),
    );
    await tester.tap(find.byKey(const Key('demo-role-profile-confirm')));
    await tester.pumpAndSettle();

    expect(
      repository
          .session('inspiration')
          .roleProfiles['alice']!
          .referenceAssetIds,
      ['scene2'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all account preference fields save and restore', (tester) async {
    final repository = await _pumpSettings(tester);
    await tester.ensureVisible(find.byTooltip('账号偏好'));
    await tester.tap(find.byTooltip('账号偏好'));
    await tester.pumpAndSettle();

    final form = find.byKey(const Key('demo-preferences-form'));
    final scrollable = find
        .descendant(of: form, matching: find.byType(Scrollable))
        .first;
    Future<void> enter(Key key, String value) async {
      final field = find.byKey(key);
      await tester.scrollUntilVisible(field, 100, scrollable: scrollable);
      await tester.enterText(field, value);
    }

    await enter(const Key('demo-preference-direction'), '治愈系故事');
    await enter(const Key('demo-preference-positioning'), '陪伴年轻创作者');
    await enter(const Key('demo-preference-feeling'), '温暖');
    await enter(const Key('demo-preference-format'), '图文和短视频');
    await enter(const Key('demo-preference-audience'), '年轻创作者');
    await tester.ensureVisible(
      find.byKey(const Key('demo-preferences-confirm')),
    );
    await tester.tap(find.byKey(const Key('demo-preferences-confirm')));
    await tester.pumpAndSettle();

    final session = repository.session('inspiration');
    expect(session.direction, '治愈系故事');
    expect(session.positioning, '陪伴年轻创作者');
    expect(session.accountPreferences['feeling'], '温暖');
    expect(session.accountPreferences['format'], '图文和短视频');
    expect(session.accountPreferences['audience'], '年轻创作者');

    await tester.ensureVisible(find.byTooltip('账号偏好'));
    await tester.tap(find.byTooltip('账号偏好'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('demo-preference-format')))
          .controller!
          .text,
      '图文和短视频',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('member name avatar and background persist after confirmation', (
    tester,
  ) async {
    final repository = await _pumpSettings(tester);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-edit-member-popi')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('demo-member-name')), '小波比');
    await tester.ensureVisible(
      find.byKey(const ValueKey('demo-avatar-rabbit')),
    );
    await tester.tap(find.byKey(const ValueKey('demo-avatar-rabbit')));
    final color = find.byKey(const ValueKey('demo-member-color-4293188862'));
    final scroll = find.byKey(const Key('demo-edit-member-scroll'));
    await tester.scrollUntilVisible(
      color,
      120,
      scrollable: find
          .descendant(of: scroll, matching: find.byType(Scrollable))
          .first,
    );
    await tester.drag(scroll, const Offset(0, -100));
    await tester.pumpAndSettle();
    final confirm = find.descendant(
      of: find.byKey(const Key('demo-member-edit-confirm')),
      matching: find.byType(FilledButton),
    );
    expect(tester.getRect(color).bottom, lessThan(tester.getRect(confirm).top));
    await tester.tap(color);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final session = repository.session('inspiration');
    expect(session.memberNames['popi'], '小波比');
    expect(session.memberAvatars['popi'], contains('rabbit'));
    expect(session.memberColors['popi'], 0xFFE4DCFE);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual work mode refreshes session capability grants', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _CatalogRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    await _pumpSettings(tester, repository: repository);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byKey(const PageStorageKey('demo-settings-skills')),
          matching: find.byType(Scrollable),
        )
        .first;
    final workMode = find.byKey(const Key('demo-work-mode'));
    await tester.scrollUntilVisible(workMode, 240, scrollable: scrollable);
    await tester.tap(workMode);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-work-mode-manual')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-active-member-writer')));
    await tester.tap(find.byKey(const Key('demo-work-mode-confirm')));
    await tester.pumpAndSettle();

    expect(repository.session('inspiration').workMode, 'manual');
    expect(repository.session('inspiration').activeMemberId, 'writer');
    expect(repository.requestedSessionIds, ['inspiration', 'inspiration']);
    expect(
      find.byKey(const ValueKey('demo-dsh-tools-web_search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('demo-dsh-tools-media_generate')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('demo-dsh-tools-web_fetch')),
      findsNothing,
    );
    expect(find.text('本会话未启用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
