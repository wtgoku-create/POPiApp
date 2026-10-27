import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/data/demo_website_character_catalog.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_remote_media.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_role_profile_preview_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _aliceProfile = DemoRoleProfile(
  name: '测试爱丽丝',
  instructions: '性格与表达风格：温柔克制\n面向受众：校园故事读者\n内容标签：青春、治愈\n爱丽丝完整原文尾句',
  revision: 'opaque-alice-revision',
  referenceAssetIds: ['scene1', 'scene2'],
);

const _erProfile = DemoRoleProfile(
  name: '测试尔尔',
  instructions: '性格与表达风格：直接明快\n面向受众：年轻创作者\n内容标签：冒险\n尔尔完整原文尾句',
  revision: 'opaque-er-revision',
  referenceAssetIds: ['scene3'],
);

Future<DemoRepository> _offlineRepository() async {
  SharedPreferences.setMockInitialValues({});
  return DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required DemoRepository repository,
  List<String> roleIds = const ['alice', 'er'],
  String initialRoleId = 'alice',
  Map<String, DemoRoleProfile> profiles = const {
    'alice': _aliceProfile,
    'er': _erProfile,
  },
  Set<String> editableRoleIds = const {},
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
  ValueChanged<String?>? onClosed,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open-role-preview'),
              onPressed: () async {
                final result = await showDemoRoleProfilePreview(
                  context,
                  repository: repository,
                  sessionId: 'inspiration',
                  roleIds: roleIds,
                  initialRoleId: initialRoleId,
                  profileSnapshots: profiles,
                  editableRoleIds: editableRoleIds,
                );
                onClosed?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-role-preview')));
  await tester.pumpAndSettle();
}

List<String> _visibleOwnedReferenceIds(WidgetTester tester) => find
    .byType(DemoAssetImage)
    .evaluate()
    .map((element) => (element.widget as DemoAssetImage).asset.id)
    .toList();

void main() {
  testWidgets('role paging follows roleIds and replaces all role content', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    await _pumpPreview(tester, repository: repository);

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('测试爱丽丝'), findsOneWidget);
    expect(find.text('温柔克制'), findsOneWidget);
    expect(_visibleOwnedReferenceIds(tester), ['scene1']);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('demo-role-preview-previous')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('demo-role-preview-next')));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('测试爱丽丝'), findsNothing);
    expect(find.text('温柔克制'), findsNothing);
    expect(find.text('测试尔尔'), findsOneWidget);
    expect(find.text('直接明快'), findsOneWidget);
    expect(_visibleOwnedReferenceIds(tester), ['scene3']);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('demo-role-preview-next')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('demo-role-preview-previous')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialRoleId selects the requested role without paging first', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    await _pumpPreview(tester, repository: repository, initialRoleId: 'er');

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('测试尔尔'), findsOneWidget);
    expect(_visibleOwnedReferenceIds(tester), ['scene3']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview sheet uses the shared rounded AppSheet surface', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    await _pumpPreview(tester, repository: repository);

    final material = tester.widget<Material>(
      find.byKey(const Key('demo-role-preview-sheet')),
    );
    expect(
      material.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(40)),
    );
    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(
      (bottomSheet.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(40)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('full instructions are hidden until explicitly expanded', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    await _pumpPreview(
      tester,
      repository: repository,
      roleIds: const ['alice'],
    );

    expect(
      find.byKey(const Key('demo-role-preview-instructions')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('demo-role-preview-instructions-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('爱丽丝完整原文尾句'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('demo-role-preview-instructions-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('demo-role-preview-instructions')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opaque revisions and absent fields are presented honestly', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    await _pumpPreview(
      tester,
      repository: repository,
      roleIds: const ['custom:blank'],
      initialRoleId: 'custom:blank',
      profiles: const {
        'custom:blank': DemoRoleProfile(
          name: '空白角色',
          revision: 'sha256:opaque-do-not-display-as-version',
          referenceAssetIds: ['missing-reference'],
        ),
      },
    );

    expect(find.text('未设置'), findsNWidgets(3));
    expect(find.textContaining('opaque-do-not-display'), findsNothing);
    expect(find.textContaining('已存证'), findsNothing);
    expect(
      find.byKey(const Key('demo-role-preview-reference-empty')),
      findsOneWidget,
    );
    expect(find.text('1 张参考图暂不可用'), findsOneWidget);
    final empty = find.byKey(const Key('demo-role-preview-reference-empty'));
    expect(
      find.descendant(of: empty, matching: find.byType(Image)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview is read only and edit returns only the requested role', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    final before = repository.session('inspiration').toJson();
    String? result;
    await _pumpPreview(
      tester,
      repository: repository,
      editableRoleIds: const {'alice'},
      onClosed: (value) => result = value,
    );

    await tester.tap(find.byKey(const Key('demo-role-preview-edit')));
    await tester.pumpAndSettle();

    expect(result, 'alice');
    expect(repository.session('inspiration').toJson(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'linked role refreshes from the current profile over its snapshot',
    (tester) async {
      final repository = await _offlineRepository();
      addTearDown(repository.dispose);
      await _pumpPreview(
        tester,
        repository: repository,
        roleIds: const ['alice'],
        editableRoleIds: const {'alice'},
      );
      expect(find.text('测试爱丽丝'), findsOneWidget);

      const current = DemoRoleProfile(
        name: '实时爱丽丝',
        instructions: '性格与表达风格：实时沉稳\n面向受众：实时受众\n内容标签：实时标签',
        revision: 'current-revision',
        referenceAssetIds: ['scene4'],
      );
      await repository.updateSession(
        'inspiration',
        (session) => session.copyWith(
          roleProfiles: {...session.roleProfiles, 'alice': current},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('实时爱丽丝'), findsOneWidget);
      expect(find.text('测试爱丽丝'), findsNothing);
      expect(find.text('实时沉稳'), findsOneWidget);
      expect(_visibleOwnedReferenceIds(tester), ['scene4']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unlinking a role revokes edit but keeps the opened catalog browsable',
    (tester) async {
      final repository = await _offlineRepository();
      addTearDown(repository.dispose);
      await _pumpPreview(
        tester,
        repository: repository,
        editableRoleIds: const {'alice', 'er'},
      );
      expect(find.byKey(const Key('demo-role-preview-edit')), findsOneWidget);

      await repository.updateSession(
        'inspiration',
        (session) => session.copyWith(
          roles: session.roles.where((roleId) => roleId != 'alice').toList(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('demo-role-preview-edit')), findsNothing);
      expect(find.byKey(const Key('demo-role-preview-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('demo-role-preview-next')));
      await tester.pumpAndSettle();
      expect(find.text('测试尔尔'), findsOneWidget);
      expect(find.byKey(const Key('demo-role-preview-edit')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('demo-role-preview-instructions-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('尔尔完整原文尾句'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting the current session safely closes its preview', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    await _pumpPreview(tester, repository: repository);
    expect(find.byKey(const Key('demo-role-preview-sheet')), findsOneWidget);

    await repository.deleteSession('inspiration');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-role-preview-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session deletion waits for an open reference gallery to close', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    await _pumpPreview(tester, repository: repository);
    await tester.tap(find.byKey(const Key('demo-role-preview-reference')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('asset-preview-gallery')), findsOneWidget);

    await repository.deleteSession('inspiration');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('asset-preview-gallery')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('asset-preview-gallery')), findsNothing);
    expect(find.byKey(const Key('demo-role-preview-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public references never receive private access headers', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    await _pumpPreview(
      tester,
      repository: repository,
      roleIds: const ['custom:public'],
      initialRoleId: 'custom:public',
      profiles: const {
        'custom:public': DemoRoleProfile(
          name: '公开角色',
          referenceImageUrls: ['https://public.example.test/role.png'],
        ),
      },
    );

    final publicImages = tester.widgetList<AppNetworkImage>(
      find.byType(AppNetworkImage),
    );
    expect(publicImages, isNotEmpty);
    expect(publicImages.every((image) => image.headers.isEmpty), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('known official CDN reference uses its bundled image copy', (
    tester,
  ) async {
    final repository = await _offlineRepository();
    addTearDown(repository.dispose);
    const roleId = 'popi-character-1058';
    final profile = DemoWebsiteCharacterCatalog.profile(roleId)!;
    final sourceUrl = profile.referenceImageUrls.single;
    final bundledPath = DemoWebsiteCharacterCatalog.bundledReferenceImage(
      sourceUrl,
    )!;
    await _pumpPreview(
      tester,
      repository: repository,
      roleIds: const [roleId],
      initialRoleId: roleId,
      profiles: {roleId: profile},
    );

    final assetPaths = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .map(
          (provider) =>
              provider is ResizeImage ? provider.imageProvider : provider,
        )
        .whereType<AssetImage>()
        .map((provider) => provider.assetName);
    expect(assetPaths, contains(bundledPath));
    expect(
      tester
          .widgetList<AppNetworkImage>(find.byType(AppNetworkImage))
          .where((image) => image.url == sourceUrl),
      isEmpty,
    );
    expect(profile.referenceImageUrls, [sourceUrl]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owned references keep the authenticated image provider', (
    tester,
  ) async {
    const asset = DemoAsset(
      id: 'owned-role-image',
      title: '私有角色图',
      kind: DemoAssetKind.image,
      cover: '',
      contentUrl:
          'http://127.0.0.1:3084/api_agent/v2/assets/owned-role-image/content',
      thumbnailUrl:
          'http://127.0.0.1:3084/api_agent/v2/assets/owned-role-image/thumbnail',
    );
    const session = DemoSession(
      id: 'owned-preview',
      title: 'Owned preview',
      kind: DemoSessionKind.project,
      members: ['popi'],
      roles: ['custom:owned'],
      messages: [],
      roleProfiles: {
        'custom:owned': DemoRoleProfile(
          name: '私有角色',
          referenceAssetIds: ['owned-role-image'],
        ),
      },
    );
    SharedPreferences.setMockInitialValues({
      DemoRepository.storageKey: jsonEncode({
        'sessions': [session.toJson()],
        'assets': [asset.toJson()],
      }),
    });
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    addTearDown(repository.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          harnessAccessHeadersProvider.overrideWith(
            (ref, url) => const {'Cookie': 'private-session'},
          ),
          harnessAccessCacheKeyProvider.overrideWith(
            (ref, url) => '$url::private-session',
          ),
          harnessAccessUnauthorizedProvider.overrideWith((ref, url) => () {}),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDemoRoleProfilePreview(
                  context,
                  repository: repository,
                  sessionId: 'owned-preview',
                  roleIds: const ['custom:owned'],
                  initialRoleId: 'custom:owned',
                ),
                child: const Text('Open owned'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open owned'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final images = tester.widgetList<Image>(
      find.descendant(
        of: find.byKey(const Key('demo-role-preview-sheet')),
        matching: find.byType(Image),
      ),
    );
    final providers = images
        .map((image) => image.image)
        .whereType<ResizeImage>()
        .map((image) => image.imageProvider)
        .whereType<CachedNetworkImageProvider>();
    expect(providers, isNotEmpty);
    expect(
      providers.every(
        (provider) => provider.headers?['Cookie'] == 'private-session',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final layout in <({String name, Size size, double scale, bool dark})>[
    (name: '320px phone', size: const Size(320, 700), scale: 1, dark: false),
    (
      name: '390px large text',
      size: const Size(390, 844),
      scale: 1.5,
      dark: false,
    ),
    (name: 'desktop dark', size: const Size(1024, 800), scale: 1.3, dark: true),
  ]) {
    testWidgets('preview has no overflow on ${layout.name}', (tester) async {
      final repository = await _offlineRepository();
      addTearDown(repository.dispose);
      await _pumpPreview(
        tester,
        repository: repository,
        size: layout.size,
        textScale: layout.scale,
        dark: layout.dark,
      );

      expect(find.byKey(const Key('demo-role-preview-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
