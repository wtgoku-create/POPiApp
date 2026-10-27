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
  Size size = const Size(375, 812),
  List<NavigatorObserver> navigatorObservers = const [],
}) async {
  tester.view.physicalSize = size;
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
        navigatorObservers: navigatorObservers,
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

Future<void> _showCapabilityCatalog(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const PageStorageKey('demo-settings-skills')),
    const Offset(0, -440),
  );
  await tester.pumpAndSettle();
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

class _FailingHarnessCatalogRepository extends DemoRepository {
  _FailingHarnessCatalogRepository(super.storage);

  @override
  bool get isHarness => true;

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

class _InstalledSkillRepository extends DemoRepository {
  _InstalledSkillRepository(super.storage);

  bool failNextSave = false;
  final List<({String memberId, String skillId, bool enabled})> saves = [];

  @override
  bool get isHarness => true;

  @override
  Future<DemoCapabilityCatalog> loadCapabilityCatalog({
    String? sessionId,
  }) async => DemoCapabilityCatalog(
    skills: [
      const DemoRuntimeCapability(
        id: demoStyleFilmSkillId,
        name: '制作风格短片',
        source: 'installed',
        installed: true,
        bound: true,
        available: true,
      ),
      DemoRuntimeCapability(
        id: demoSeedanceReferenceRemixSkillId,
        name: '三案例仿写：先图后视频',
        description: '生成三份配套提示词',
        source: 'installed',
        installed: true,
        bound: true,
        granted: session(sessionId ?? 'inspiration')
            .skillsFor(session(sessionId ?? 'inspiration').activeMemberId)
            .contains(demoSeedanceReferenceRemixSkillId),
        available: true,
      ),
      DemoRuntimeCapability(
        id: 'ffmpeg-video-edit',
        name: '通用视频剪辑',
        description: '裁切、拼接、字幕和音轨处理',
        source: 'installed',
        installed: true,
        bound: true,
        granted: session(sessionId ?? 'inspiration')
            .skillsFor(session(sessionId ?? 'inspiration').activeMemberId)
            .contains('ffmpeg-video-edit'),
        available: true,
      ),
      DemoRuntimeCapability(
        id: 'future-case-skill',
        name: '未来安装能力',
        description: '由服务端目录发现',
        source: 'installed',
        installed: true,
        bound: true,
        granted: session(sessionId ?? 'inspiration')
            .skillsFor(session(sessionId ?? 'inspiration').activeMemberId)
            .contains('future-case-skill'),
        available: true,
      ),
    ],
  );

  @override
  Future<void> setMemberSkillEnabled(
    String sessionId, {
    required String memberId,
    required String skillId,
    required bool enabled,
  }) async {
    saves.add((memberId: memberId, skillId: skillId, enabled: enabled));
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    await super.setMemberSkillEnabled(
      sessionId,
      memberId: memberId,
      skillId: skillId,
      enabled: enabled,
    );
  }
}

class _AssociationRaceRepository extends DemoRepository {
  _AssociationRaceRepository(super.storage);

  bool _aliceUnlinked = false;

  void unlinkAliceSynchronously() {
    _aliceUnlinked = true;
    notifyListeners();
  }

  DemoSession _project(DemoSession session) => !_aliceUnlinked
      ? session
      : session.copyWith(
          roles: session.roles.where((roleId) => roleId != 'alice').toList(),
        );

  @override
  List<DemoSession> get sessions => super.sessions.map(_project).toList();

  @override
  DemoSession session(String id) => _project(super.session(id));
}

class _UnlinkOnPopObserver extends NavigatorObserver {
  _UnlinkOnPopObserver(this.repository);

  final _AssociationRaceRepository repository;
  bool _handled = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_handled) return;
    _handled = true;
    repository.unlinkAliceSynchronously();
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
      await tester.tap(
        find.byKey(const Key('demo-role-preview-instructions-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('性格：活泼开朗'), findsOneWidget);
      expect(find.textContaining('不将多视图当作多个人物'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(repository.session('inspiration').roles, isNot(contains(roleId)));
      expect(repository.session('inspiration').roleProfiles[roleId], isNull);
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

  testWidgets('legacy Alice association saves its verified website profile', (
    tester,
  ) async {
    final repository = await _pumpSettings(tester);
    expect(repository.session('inspiration').roleProfiles['alice'], isNull);

    await tester.tap(find.byKey(const Key('demo-settings-roles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-roles-confirm')));
    await tester.pumpAndSettle();

    expect(
      repository.session('inspiration').roleProfiles['alice']?.toJson(),
      DemoWebsiteCharacterCatalog.profile('alice')?.toJson(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved Alice edits remain ahead of website defaults', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    const edited = DemoRoleProfile(
      name: '我的爱丽丝',
      instructions: '用户保存的角色设定',
      revision: 'user-alice-revision',
    );
    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(
        roleProfiles: {...session.roleProfiles, 'alice': edited},
      ),
    );
    await _pumpSettings(tester, repository: repository);

    await tester.tap(find.byKey(const Key('demo-settings-roles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-roles-confirm')));
    await tester.pumpAndSettle();

    expect(
      repository.session('inspiration').roleProfiles['alice']?.toJson(),
      edited.toJson(),
    );
    expect(tester.takeException(), isNull);
  });

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
      expect(
        find.byKey(const ValueKey('demo-style-film-capability-popi')),
        findsOneWidget,
      );
      await _showCapabilityCatalog(tester);

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
        find.descendant(of: mcp, matching: find.text('尚未接入')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: skills,
          matching: find.byKey(
            const ValueKey('demo-style-film-capability-popi'),
          ),
        ),
        findsOneWidget,
      );
      for (final section in [tools, mcp]) {
        expect(
          find.descendant(of: section, matching: find.byType(Switch)),
          findsNothing,
        );
      }
      expect(find.text('添加能力'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'future catalog Skill uses the generic toggle without app enums',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _InstalledSkillRepository(
        PreferencesStorage(await SharedPreferences.getInstance()),
      )..restore();
      await _pumpSettings(
        tester,
        repository: repository,
        size: const Size(390, 844),
      );
      await tester.tap(find.text('能力'));
      await tester.pumpAndSettle();
      await _showCapabilityCatalog(tester);
      final toggle = find.byKey(
        const ValueKey('demo-installed-skill-toggle-future-case-skill-popi'),
      );
      await tester.ensureVisible(toggle);
      expect(toggle, findsOneWidget);
      tester.widget<Switch>(toggle).onChanged?.call(true);
      await tester.pumpAndSettle();
      expect(repository.saves.single, (
        memberId: 'popi',
        skillId: 'future-case-skill',
        enabled: true,
      ));
      expect(
        repository.session('inspiration').skillsFor('popi'),
        contains('future-case-skill'),
      );
      expect(
        repository.session('inspiration').skillsFor('writer'),
        isNot(contains('future-case-skill')),
      );
    },
  );

  testWidgets(
    'installed Skill autosaves only for the active Bot and preserves other skills',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _InstalledSkillRepository(
        PreferencesStorage(await SharedPreferences.getInstance()),
      )..restore();
      await repository.updateSession(
        'inspiration',
        (session) => session.copyWith(
          members: const ['popi'],
          activeMemberId: 'popi',
          memberSkills: const {
            'popi': [demoStyleFilmSkillId],
            'writer': ['writer-existing-skill'],
          },
        ),
      );
      await _pumpSettings(
        tester,
        repository: repository,
        size: const Size(390, 844),
      );
      await tester.tap(find.text('能力'));
      await tester.pumpAndSettle();
      await _showCapabilityCatalog(tester);

      const toggleKey = ValueKey(
        'demo-installed-skill-toggle-seedance-reference-remix-popi',
      );
      final toggle = find.byKey(toggleKey);
      await tester.ensureVisible(toggle);
      expect(toggle, findsOneWidget);
      expect(find.text('三案例仿写：先图后视频'), findsOneWidget);
      expect(find.text('生成三份配套提示词'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('demo-dsh-skills')),
          matching: find.text('制作风格短片'),
        ),
        findsOneWidget,
      );
      final styleToggle = find.byKey(
        const ValueKey('demo-style-film-capability-popi'),
      );
      expect(styleToggle, findsOneWidget);
      expect(
        tester.getTopLeft(styleToggle).dy,
        lessThan(tester.getTopLeft(toggle).dy),
      );
      expect(find.text('通用视频剪辑'), findsOneWidget);

      tester.widget<Switch>(toggle).onChanged?.call(true);
      await tester.pumpAndSettle();
      expect(repository.saves.single, (
        memberId: 'popi',
        skillId: demoSeedanceReferenceRemixSkillId,
        enabled: true,
      ));
      expect(
        repository.session('inspiration').skillsFor('popi'),
        containsAll([demoStyleFilmSkillId, demoSeedanceReferenceRemixSkillId]),
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey(
              'demo-installed-skill-seedance-reference-remix-popi',
            ),
          ),
          matching: find.textContaining('本会话已启用'),
        ),
        findsOneWidget,
      );
      expect(repository.session('inspiration').skillsFor('writer'), [
        'writer-existing-skill',
      ]);

      tester.widget<Switch>(toggle).onChanged?.call(false);
      await tester.pumpAndSettle();
      expect(repository.saves.last, (
        memberId: 'popi',
        skillId: demoSeedanceReferenceRemixSkillId,
        enabled: false,
      ));
      expect(repository.session('inspiration').skillsFor('popi'), [
        demoStyleFilmSkillId,
      ]);
      expect(repository.session('inspiration').skillsFor('writer'), [
        'writer-existing-skill',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy members keep one independent style toggle each', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _InstalledSkillRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(
        members: const ['popi', 'writer'],
        activeMemberId: 'popi',
        memberSkills: const {
          'popi': ['future-case-skill'],
          'writer': ['ffmpeg-video-edit'],
        },
      ),
    );
    await _pumpSettings(tester, repository: repository);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    await _showCapabilityCatalog(tester);

    final skills = find.byKey(const ValueKey('demo-dsh-skills'));
    expect(
      find.descendant(
        of: skills,
        matching: find.byKey(const ValueKey('demo-style-film-capability-popi')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: skills,
        matching: find.byKey(
          const ValueKey('demo-style-film-capability-writer'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: skills, matching: find.text('制作风格短片')),
      findsNWidgets(2),
    );
    final popiToggle = find.byKey(
      const ValueKey('demo-style-film-capability-popi'),
    );
    final writerToggle = find.byKey(
      const ValueKey('demo-style-film-capability-writer'),
    );
    await tester.ensureVisible(writerToggle);
    expect(tester.widget<Switch>(popiToggle).value, isFalse);
    expect(tester.widget<Switch>(writerToggle).value, isFalse);

    tester.widget<Switch>(popiToggle).onChanged?.call(true);
    await tester.pumpAndSettle();
    expect(repository.session('inspiration').skillsFor('popi'), [
      'future-case-skill',
      demoStyleFilmSkillId,
    ]);
    expect(repository.session('inspiration').skillsFor('writer'), [
      'ffmpeg-video-edit',
    ]);

    tester.widget<Switch>(writerToggle).onChanged?.call(true);
    await tester.pumpAndSettle();
    expect(repository.session('inspiration').skillsFor('popi'), [
      'future-case-skill',
      demoStyleFilmSkillId,
    ]);
    expect(repository.session('inspiration').skillsFor('writer'), [
      'ffmpeg-video-edit',
      demoStyleFilmSkillId,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed installed Skill save keeps the draft but never reports it enabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _InstalledSkillRepository(
        PreferencesStorage(await SharedPreferences.getInstance()),
      )..restore();
      repository.failNextSave = true;
      await _pumpSettings(tester, repository: repository);
      await tester.tap(find.text('能力'));
      await tester.pumpAndSettle();
      await _showCapabilityCatalog(tester);

      final row = find.byKey(
        const ValueKey('demo-installed-skill-seedance-reference-remix-popi'),
      );
      final toggle = find.byKey(
        const ValueKey(
          'demo-installed-skill-toggle-seedance-reference-remix-popi',
        ),
      );
      await tester.ensureVisible(toggle);
      tester.widget<Switch>(toggle).onChanged?.call(true);
      await tester.pumpAndSettle();

      expect(
        repository.session('inspiration').skillsFor('popi'),
        isNot(contains(demoSeedanceReferenceRemixSkillId)),
      );
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(
        find.descendant(of: row, matching: find.textContaining('本会话未启用')),
        findsOneWidget,
      );
      expect(find.text('Skill 设置未保存，已保留你的选择。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  for (final size in const [Size(320, 720), Size(390, 844), Size(1180, 820)]) {
    testWidgets(
      'installed Skill remains accessible without overflow at ${size.width}px',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final repository = _InstalledSkillRepository(
          PreferencesStorage(await SharedPreferences.getInstance()),
        )..restore();
        await _pumpSettings(tester, repository: repository, size: size);
        await tester.tap(find.text('能力'));
        await tester.pumpAndSettle();
        await _showCapabilityCatalog(tester);
        final toggle = find.byKey(
          const ValueKey(
            'demo-installed-skill-toggle-seedance-reference-remix-popi',
          ),
        );
        await tester.ensureVisible(toggle);
        final semantics = tester.ensureSemantics();
        expect(
          find.bySemanticsLabel(RegExp(r'三案例仿写：先图后视频.*POPi')),
          findsOneWidget,
        );
        semantics.dispose();
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('offline catalog states that DSH bindings are not connected', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    await _showCapabilityCatalog(tester);

    expect(find.text('尚未接入'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('demo-dsh-skills')),
        matching: find.byKey(const ValueKey('demo-style-film-capability-popi')),
      ),
      findsOneWidget,
    );
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

  testWidgets('catalog failure keeps enabled legacy style skills removable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FailingHarnessCatalogRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(
        members: const ['popi'],
        activeMemberId: 'popi',
        memberSkills: const {
          'popi': [demoStyleFilmSkillId, 'future-case-skill'],
        },
      ),
    );
    await _pumpSettings(tester, repository: repository);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();

    final skills = find.byKey(const ValueKey('demo-dsh-skills'));
    final toggle = find.byKey(
      const ValueKey('demo-style-film-capability-popi'),
    );
    expect(find.byKey(const ValueKey('demo-dsh-tools')), findsNothing);
    expect(find.byKey(const ValueKey('demo-dsh-mcp')), findsNothing);
    expect(find.descendant(of: skills, matching: toggle), findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isTrue);

    tester.widget<Switch>(toggle).onChanged?.call(false);
    await tester.pumpAndSettle();
    expect(repository.session('inspiration').skillsFor('popi'), [
      'future-case-skill',
    ]);
    expect(tester.takeException(), isNull);
    toastification.dismissAll(delayForAnimation: false);
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
    await _showCapabilityCatalog(tester);
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
    await tester.tap(find.byKey(const Key('demo-role-preview-edit')));
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
    await tester.tap(find.byKey(const Key('demo-role-preview-edit')));
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

  testWidgets('stale preview edit result cannot reopen an unlinked role form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _AssociationRaceRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    final observer = _UnlinkOnPopObserver(repository);
    await _pumpSettings(
      tester,
      repository: repository,
      navigatorObservers: [observer],
    );
    await tester.tap(find.byKey(const ValueKey('demo-role-profile-alice')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('demo-role-preview-edit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('demo-role-profile-instructions')),
      findsNothing,
    );
    expect(repository.session('inspiration').roles, isNot(contains('alice')));
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
