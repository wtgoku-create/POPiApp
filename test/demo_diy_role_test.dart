import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/demo_role_mentions.dart';
import 'package:popi_ai_app/features/demo/domain/demo_upload_file.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_diy_role_sheet.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_content_role_avatar.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  late _DiyRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = _DiyRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    );
    repository.restore();
  });

  tearDown(() => repository.dispose());

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget diyLauncher({required Future<List<DemoUploadFile>> Function() pick}) =>
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDemoDiyRoleSheet(
              context,
              repository,
              'inspiration',
              pickFiles: pick,
            ),
            child: const Text('DIY'),
          ),
        ),
      );

  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (condition()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      if (condition()) return;
    }
    fail('Condition was not reached after 40 frames');
  }

  Future<void> pickImages(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('demo-diy-role-picker')));
    await tester.pump();
    await pumpUntil(tester, () {
      final picker = find.byKey(const Key('demo-diy-role-picker'));
      final files = find.byKey(const Key('demo-diy-role-files'));
      return picker.evaluate().isNotEmpty &&
          files.evaluate().isNotEmpty &&
          tester.widget<OutlinedButton>(picker).onPressed != null;
    });
  }

  testWidgets(
    'add members is disabled while existing assistant remains editable',
    (tester) async {
      await pump(
        tester,
        DemoSettingsPage(
          repository: repository,
          sessionId: 'inspiration',
          initialTab: 1,
        ),
      );

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
    },
  );

  testWidgets('selected image uploads and saves a reusable role profile', (
    tester,
  ) async {
    final image = _image('diy-image', '小狐狸.png');
    await pump(tester, diyLauncher(pick: () async => [image]));

    await tester.tap(find.text('DIY'));
    await tester.pumpAndSettle();
    await pickImages(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('demo-diy-role-name')))
          .controller!
          .text,
      '小狐狸',
    );
    await tester.enterText(
      find.byKey(const Key('demo-diy-role-description')),
      '橘色短毛，性格机灵',
    );
    await tester.tap(find.byKey(const Key('demo-diy-role-save')));
    await pumpUntil(
      tester,
      () => find.byKey(const Key('demo-diy-role-name')).evaluate().isEmpty,
    );

    final session = repository.session('inspiration');
    final roleId = session.roles.singleWhere((id) => id.startsWith('custom:'));
    expect(roleId, isNot('custom:小狐狸'));
    final profile = session.roleProfiles[roleId]!;
    expect(profile.name, '小狐狸');
    expect(profile.instructions, '橘色短毛，性格机灵');
    expect(profile.referenceAssetIds, ['asset-diy-image']);
    expect(profile.revision, isNotEmpty);
    expect(repository.uploadCalls, ['diy-image']);
    expect(
      DemoRoleMentionTracker().resolve(
        draft: '@小狐狸 做一张角色海报',
        linkedRoleIds: session.roles,
        roleNames: {
          for (final entry in session.roleProfiles.entries)
            entry.key: entry.value.name,
        },
      ),
      [roleId],
    );
  });

  testWidgets('failed upload keeps draft and retry skips successful files', (
    tester,
  ) async {
    final first = _image('first', '第一张.png');
    final second = _image('second', '第二张.png');
    repository.failOnceId = 'second';
    await pump(tester, diyLauncher(pick: () async => [first, second]));

    await tester.tap(find.text('DIY'));
    await tester.pumpAndSettle();
    await pickImages(tester);
    await tester.enterText(
      find.byKey(const Key('demo-diy-role-description')),
      '保留这段草稿',
    );
    await tester.tap(find.byKey(const Key('demo-diy-role-save')));
    await pumpUntil(tester, () => repository.uploadCalls.length == 2);
    await pumpUntil(tester, () {
      final save = find.descendant(
        of: find.byKey(const Key('demo-diy-role-save')),
        matching: find.byType(FilledButton),
      );
      return save.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(save).onPressed != null;
    });

    expect(repository.uploadCalls, ['first', 'second']);
    expect(find.text('保留这段草稿'), findsOneWidget);
    expect(find.byKey(const Key('demo-diy-role-files')), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-diy-role-save')));
    await pumpUntil(
      tester,
      () => find.byKey(const Key('demo-diy-role-name')).evaluate().isEmpty,
    );
    expect(repository.uploadCalls, ['first', 'second', 'second']);
    expect(find.byKey(const Key('demo-diy-role-name')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });

  testWidgets('closing an idle DIY draft performs no upload or session write', (
    tester,
  ) async {
    await pump(
      tester,
      diyLauncher(pick: () async => [_image('cancelled', '不保存.png')]),
    );
    await tester.tap(find.text('DIY'));
    await tester.pumpAndSettle();
    await pickImages(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(repository.uploadCalls, isEmpty);
    expect(repository.updateCalls, isEmpty);
    expect(
      repository
          .session('inspiration')
          .roles
          .where((id) => id.startsWith('custom:')),
      isEmpty,
    );
  });

  testWidgets('failed profile save retries without reuploading its image', (
    tester,
  ) async {
    repository.failNextUpdate = true;
    await pump(
      tester,
      diyLauncher(pick: () async => [_image('saved-once', '不重传.png')]),
    );
    await tester.tap(find.text('DIY'));
    await tester.pumpAndSettle();
    await pickImages(tester);
    await tester.tap(find.byKey(const Key('demo-diy-role-save')));
    await pumpUntil(tester, () => repository.updateCalls.length == 1);
    await pumpUntil(tester, () {
      final save = find.descendant(
        of: find.byKey(const Key('demo-diy-role-save')),
        matching: find.byType(FilledButton),
      );
      return save.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(save).onPressed != null;
    });

    expect(repository.uploadCalls, ['saved-once']);
    expect(find.byKey(const Key('demo-diy-role-name')), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-diy-role-save')));
    await pumpUntil(
      tester,
      () => find.byKey(const Key('demo-diy-role-name')).evaluate().isEmpty,
    );

    expect(repository.uploadCalls, ['saved-once']);
    expect(
      repository
          .session('inspiration')
          .roles
          .where((id) => id.startsWith('custom:')),
      hasLength(1),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });

  testWidgets('name alone cannot save a role without instructions or images', (
    tester,
  ) async {
    await pump(tester, diyLauncher(pick: () async => const []));
    await tester.tap(find.text('DIY'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('demo-diy-role-name')), '只有名字');

    final save = find.descendant(
      of: find.byKey(const Key('demo-diy-role-save')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('demo-diy-role-description')),
      '补充一条可用于生成的角色设定',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('five linked roles block upload with the role-specific limit', (
    tester,
  ) async {
    await tester.runAsync(
      () => repository.updateSession(
        'inspiration',
        (session) =>
            session.copyWith(roles: const ['r1', 'r2', 'r3', 'r4', 'r5']),
      ),
    );
    repository.updateCalls.clear();
    await pump(
      tester,
      diyLauncher(pick: () async => [_image('blocked', '第六个角色.png')]),
    );
    await tester.tap(find.text('DIY'));
    await tester.pumpAndSettle();
    await pickImages(tester);
    expect(repository.session('inspiration').roles, hasLength(5));
    final save = find.descendant(
      of: find.byKey(const Key('demo-diy-role-save')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('demo-diy-role-save')));
    await pumpUntil(tester, () => find.text('最多选择5个角色').evaluate().isNotEmpty);

    expect(find.text('最多选择5个角色'), findsOneWidget);
    expect(repository.uploadCalls, isEmpty);
    expect(repository.updateCalls, isEmpty);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });

  testWidgets('final save rechecks the role limit after the image upload', (
    tester,
  ) async {
    repository.fillRolesBeforeNextUpdate = true;
    await pump(
      tester,
      diyLauncher(pick: () async => [_image('raced', '并发角色.png')]),
    );
    await tester.tap(find.text('DIY'));
    await tester.pumpAndSettle();
    await pickImages(tester);
    await tester.tap(find.byKey(const Key('demo-diy-role-save')));
    await tester.pump();
    await pumpUntil(tester, () => find.text('最多选择5个角色').evaluate().isNotEmpty);

    expect(repository.uploadCalls, ['raced']);
    expect(find.text('最多选择5个角色'), findsOneWidget);
    expect(
      repository
          .session('inspiration')
          .roles
          .where((id) => id.startsWith('custom:')),
      isEmpty,
    );
    expect(find.byKey(const Key('demo-diy-role-name')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });

  testWidgets('saved DIY profile and reference image copy to another session', (
    tester,
  ) async {
    final image = _image('shared', '共享角色.png');
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => showDemoDiyRoleSheet(
                  context,
                  repository,
                  'inspiration',
                  pickFiles: () async => [image],
                ),
                child: const Text('Create'),
              ),
              TextButton(
                onPressed: () =>
                    showDemoRoleSheet(context, repository, 'alice'),
                child: const Text('Link'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await pickImages(tester);
    await tester.tap(find.byKey(const Key('demo-diy-role-save')));
    await pumpUntil(
      tester,
      () => find.byKey(const Key('demo-diy-role-name')).evaluate().isEmpty,
    );
    final source = repository.session('inspiration');
    final roleId = source.roles.singleWhere((id) => id.startsWith('custom:'));

    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的角色'));
    await tester.pumpAndSettle();
    expect(find.byType(DemoContentRoleAvatar), findsWidgets);
    await tester.tap(find.byKey(ValueKey('demo-role-option-$roleId')));
    await tester.tap(find.byKey(const Key('demo-roles-confirm')));
    await pumpUntil(
      tester,
      () => repository.session('alice').roles.contains(roleId),
    );

    final target = repository.session('alice');
    expect(target.roles, contains(roleId));
    expect(target.roleProfiles[roleId]?.name, '共享角色');
    expect(
      target.roleProfiles[roleId]?.referenceAssetIds,
      source.roleProfiles[roleId]?.referenceAssetIds,
    );
  });
}

class _DiyRepository extends DemoRepository {
  _DiyRepository(super.storage);

  final uploadCalls = <String>[];
  final updateCalls = <String>[];
  final _uploaded = <DemoAsset>[];
  String? failOnceId;
  bool failNextUpdate = false;
  bool fillRolesBeforeNextUpdate = false;

  @override
  List<DemoAsset> get assets => [..._uploaded, ...super.assets];

  @override
  Future<DemoAsset> uploadFile(DemoUploadFile file) async {
    uploadCalls.add(file.clientRequestId);
    if (failOnceId == file.clientRequestId) {
      failOnceId = null;
      throw const DemoUploadException('UPLOAD_FAILED');
    }
    final existing = _uploaded
        .where((asset) => asset.id == 'asset-${file.clientRequestId}')
        .firstOrNull;
    if (existing != null) return existing;
    final asset = DemoAsset(
      id: 'asset-${file.clientRequestId}',
      title: file.name,
      kind: DemoAssetKind.image,
      cover: 'assets/images/demo_role_1.png',
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
    );
    _uploaded.add(asset);
    notifyListeners();
    return asset;
  }

  @override
  Future<void> updateSession(
    String id,
    DemoSession Function(DemoSession) update,
  ) async {
    updateCalls.add(id);
    if (failNextUpdate) {
      failNextUpdate = false;
      throw StateError('save failed');
    }
    if (fillRolesBeforeNextUpdate) {
      fillRolesBeforeNextUpdate = false;
      await super.updateSession(
        id,
        (session) =>
            session.copyWith(roles: const ['r1', 'r2', 'r3', 'r4', 'r5']),
      );
    }
    await super.updateSession(id, update);
  }
}

DemoUploadFile _image(String id, String name) {
  final bytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  return DemoUploadFile(
    clientRequestId: id,
    name: name,
    mimeType: 'image/png',
    sizeBytes: bytes.length,
    kind: DemoAssetKind.image,
    readBytes: () async => bytes,
  );
}
