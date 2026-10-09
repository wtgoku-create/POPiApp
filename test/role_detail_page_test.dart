import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/assets/data/role_library_repository.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/assets/domain/role_profile_edit.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/features/assets/presentation/role_detail_page.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

import 'support/role_library_fixtures.dart';

const sample = LibraryRole(
  id: '7',
  title: '爱丽丝',
  description: '叮叮的同桌、室友和毒舌闺蜜',
  canEdit: true,
  canCreate: true,
  profileComplete: true,
  profile: {
    'expressionStyle': '嘴硬心软，表达自然轻松，保持角色既定的能力与限制。',
    'targetAudience': '喜欢校园故事、室友互损和角色互动的观众。',
    'contentTags': ['校园故事', '室友互损', '嘴硬心软'],
    'profileData': {
      'boundaries': {'label': '表达边界', 'value': '保持角色外形、配色和行为逻辑一致。不通过伤害他人推进故事。'},
    },
  },
);

void main() {
  final boundaryKey = GlobalKey();
  Future<void> capture(WidgetTester tester, String path) async {
    if (!const bool.fromEnvironment('CAPTURE_ROLE_PROFILE')) return;
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    String category = 'personal',
    Locale locale = const Locale('zh'),
    double textScale = 1,
    Future<LibraryRole> Function(String)? load,
    Future<void> Function(String)? delete,
    RoleProfileSaver? save,
    ValueChanged<LibraryRole>? onRoleUpdated,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var theme = AppTheme.light;
    if (const bool.fromEnvironment('CAPTURE_ROLE_PROFILE')) {
      await tester.runAsync(() async {
        final loader = FontLoader('ProfileCapture');
        loader.addFont(
          File(
            '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
        await loader.load();
      });
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'ProfileCapture'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'ProfileCapture',
        ),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
            roleLibraryDio(
              loadDetail: load ?? (_) async => sample,
              delete: delete,
              save: save ?? (_, _) async => sample,
            ),
          ),
        ],
        child: MaterialApp(
          theme: theme,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(key: boundaryKey, child: child!),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) => RoleDetailPage(
                      role: sample,
                      category: category,
                      onRoleUpdated: onRoleUpdated,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  test('detail and deletion use the Web studio contracts', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'data': request.method == 'DELETE'
                    ? {}
                    : {
                        'id': 7,
                        'canEdit': true,
                        'canUseText': true,
                        'isCertified': true,
                        'profileVersion': {
                          'profile': {
                            'title': 'Current',
                            'targetAudience': 'Audience',
                          },
                        },
                      },
              },
            ),
          );
        },
      ),
    );
    final api = NetworkApi(dio);
    final role = LibraryRole.fromJson(await api.libraryRoleDetail('7'));
    expect(role.title, 'Current');
    expect(role.profile['targetAudience'], 'Audience');
    expect(role.canEdit && role.canCreate && role.isCertified, isTrue);
    await api.deleteLibraryRole('7', 'request-1');
    expect(requests.first.path, '/api_client/agent/v2/roles/7');
    expect(requests.last.method, 'DELETE');
    expect(requests.last.data, {'clientRequestId': 'request-1'});
  });

  test(
    'profile saving posts the Web contract then loads fresh details',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'data': request.method == 'POST'
                      ? {}
                      : {
                          'id': '7',
                          'canEdit': true,
                          'profileVersion': {
                            'profile': {
                              'title': 'Updated',
                              'expressionStyle': 'New style',
                            },
                          },
                        },
                },
              ),
            );
          },
        ),
      );
      final profile = {
        'expressionStyle': 'New style',
        'targetAudience': 'Audience',
        'contentTags': ['Tag'],
        'profileData': <String, Object?>{},
      };

      final updated = await RoleLibraryRepository(
        NetworkApi(dio),
      ).saveProfile('7', profile);

      expect(requests.map((request) => request.method), ['POST', 'GET']);
      expect(requests.first.path, '/api_client/agent/v2/roles/7/save');
      expect(requests.first.data['profile'], profile);
      expect(
        requests.first.data['clientRequestId'],
        startsWith('mobile-role-profile-save-'),
      );
      expect(updated.title, 'Updated');
      expect(updated.profile['expressionStyle'], 'New style');
    },
  );

  test('profile edits preserve custom labels and array value types', () {
    final edit = RoleProfileEdit.fromRole(
      const LibraryRole(
        id: '7',
        title: 'Role',
        description: '',
        profile: {
          'profileData': {
            'abilities': {
              'label': '能力',
              'value': ['观察', '推理'],
            },
            'metadata': {
              'label': '信息',
              'value': {'source': 'original'},
            },
          },
        },
      ),
    );
    final result = edit.savedProfile({
      'expressionStyle': ' Style ',
      'targetAudience': ' Audience ',
      'contentTags': '校园、生活,成长，喜剧\n互动',
      'profileData-abilities': '观察、推理,表达',
    });
    expect(result['contentTags'], ['校园', '生活', '成长', '喜剧', '互动']);
    expect(result['profileData'], {
      'abilities': {
        'label': '能力',
        'value': ['观察', '推理', '表达'],
      },
      'metadata': {
        'label': '信息',
        'value': {'source': 'original'},
      },
    });
    expect(result['expressionStyle'], 'Style');
  });

  test(
    'existing positioning field replaces the legacy description fallback',
    () {
      final edit = RoleProfileEdit.fromRole(
        const LibraryRole(
          id: '7',
          title: 'Role',
          description: 'Legacy description',
          profile: {
            'profileData': {
              'positioning': {'label': '人物定位', 'value': 'Current positioning'},
            },
          },
        ),
      );
      final fields = edit.fields.where(
        (field) => field.type == RoleProfileFieldType.positioning,
      );
      expect(fields, hasLength(1));
      expect(fields.single.text, 'Current positioning');
      expect(fields.single.editable, isTrue);
    },
  );

  testWidgets(
    'legacy appearance and empty boundaries can be edited and saved',
    (tester) async {
      const legacy = LibraryRole(
        id: '7',
        title: 'Role',
        description: '原人物定位',
        canEdit: true,
        profile: {
          'expressionStyle': '原表达风格',
          'targetAudience': '原面向受众',
          'contentTags': ['原标签'],
          'appearance': '231',
        },
      );
      Map<String, Object?>? saved;
      await pumpPage(
        tester,
        load: (_) async => legacy,
        save: (_, profile) async {
          saved = profile;
          return legacy;
        },
      );
      await tester.tap(find.byKey(const Key('role-improve')));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(6));
      final appearance = find.byKey(const Key('role-edit-appearance'));
      final boundaries = find.byKey(const Key('role-edit-boundaries'));
      expect(tester.widget<TextFormField>(appearance).controller!.text, '231');
      expect(
        tester.widget<TextFormField>(boundaries).controller!.text,
        isEmpty,
      );
      await tester.ensureVisible(appearance);
      await tester.enterText(appearance, '新的外形');
      await tester.ensureVisible(boundaries);
      await tester.enterText(boundaries, '新的表达边界');
      await tester.pumpAndSettle();
      await capture(tester, '/tmp/popi-role-profile-edit-legacy.png');
      await tester.tap(find.byKey(const Key('role-edit-confirm')));
      await tester.pumpAndSettle();
      final data = saved!['profileData'] as Map;
      expect(data['appearance'], {'label': '人物外形', 'value': '新的外形'});
      expect(data['boundaries'], {'label': '表达边界', 'value': '新的表达边界'});
      expect(data['positioning'], {'label': '人物定位', 'value': '原人物定位'});
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'improve edits inline and cancellation restores original values',
    (tester) async {
      var saves = 0;
      await pumpPage(
        tester,
        save: (_, _) async {
          saves++;
          return sample;
        },
      );
      await tester.tap(find.byKey(const Key('role-improve')));
      await tester.pumpAndSettle();
      expect(find.byType(SessionPage), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(5));
      await capture(tester, '/tmp/popi-role-profile-edit.png');
      expect(find.byKey(const Key('role-create')), findsNothing);
      final field = find.byKey(const Key('role-edit-expressionStyle'));
      await tester.enterText(field, '草稿设定');
      await tester.tap(find.byKey(const Key('role-edit-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('草稿设定'), findsNothing);
      expect(saves, 0);
      await tester.tap(find.byKey(const Key('role-improve')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        sample.profile['expressionStyle'],
      );
      await tester.tap(find.byKey(const Key('role-profile-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role-detail-page')), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    },
  );

  testWidgets(
    'confirmation saves the draft once and renders fresh server values',
    (tester) async {
      final pending = Completer<LibraryRole>();
      final profiles = <Map<String, Object?>>[];
      LibraryRole? notified;
      await pumpPage(
        tester,
        save: (id, profile) {
          expect(id, '7');
          profiles.add(profile);
          return pending.future;
        },
        onRoleUpdated: (role) => notified = role,
      );
      await tester.tap(find.byKey(const Key('role-improve')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('role-edit-expressionStyle')),
        ' 更自然的表达 ',
      );
      await tester.enterText(
        find.byKey(const Key('role-edit-contentTags')),
        '校园、喜剧，成长',
      );
      await tester.tap(find.byKey(const Key('role-edit-confirm')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(profiles.single['expressionStyle'], '更自然的表达');
      expect(profiles.single['contentTags'], ['校园', '喜剧', '成长']);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('role-edit-confirm')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('role-edit-cancel')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('role-edit-expressionStyle')),
            )
            .enabled,
        isFalse,
      );
      const updated = LibraryRole(
        id: '7',
        title: '爱丽丝',
        description: '叮叮的同桌',
        canEdit: true,
        profile: {
          'expressionStyle': '服务端最新表达',
          'contentTags': ['校园', '喜剧', '成长'],
        },
      );
      pending.complete(updated);
      await tester.pumpAndSettle();
      expect(notified?.id, updated.id);
      expect(notified?.title, updated.title);
      expect(notified?.profile, updated.profile);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('服务端最新表达'), findsOneWidget);
      expect(find.text('校园 / 喜剧 / 成长'), findsNWidgets(2));
      expect(profiles, hasLength(1));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'required fields block saving and failed saves retain the draft for retry',
    (tester) async {
      var calls = 0;
      await pumpPage(
        tester,
        save: (_, _) async {
          if (++calls == 1) throw StateError('Offline');
          return sample;
        },
      );
      await tester.tap(find.byKey(const Key('role-improve')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('role-edit-expressionStyle'));
      for (final label in ['人物定位', '性格与表达风格', '面向受众', '内容标签', '表达边界']) {
        expect(find.text('$label *'), findsOneWidget);
      }
      final inputs = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      for (final input in inputs) {
        final finder = find.byKey(input.key!);
        final original = input.controller!.text;
        await tester.ensureVisible(finder);
        await tester.enterText(finder, '   ');
        await tester.pump();
        expect(find.text('请填写此项'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('role-edit-confirm')))
              .onPressed,
          isNull,
        );
        await tester.enterText(finder, original);
        await tester.pump();
      }
      await tester.ensureVisible(field);
      await tester.enterText(field, '   ');
      await tester.pump();
      expect(find.text('请填写此项'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('role-edit-confirm')))
            .onPressed,
        isNull,
      );
      expect(calls, 0);
      await tester.enterText(field, '保留我的草稿');
      await tester.pump();
      await tester.tap(find.byKey(const Key('role-edit-confirm')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, '保留我的草稿');
      expect(find.text('角色档案保存失败，请稍后重试'), findsOneWidget);
      await tester.tap(find.byKey(const Key('role-edit-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(TextFormField), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'editing actions remain reachable with keyboard and larger English text',
    (tester) async {
      await pumpPage(
        tester,
        size: const Size(320, 640),
        locale: const Locale('en'),
        textScale: 1.3,
      );
      await tester.ensureVisible(find.byKey(const Key('role-improve')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-improve')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('role-edit-cancel')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('role-edit-confirm')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .getBottomRight(find.byKey(const Key('role-profile-edit-actions')))
            .dy,
        lessThanOrEqualTo(380),
      );
      expect(tester.takeException(), isNull);
      await capture(tester, '/tmp/popi-role-profile-edit-keyboard.png');
    },
  );

  testWidgets('renders the archive and actions from real profile fields', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('角色档案'), findsOneWidget);
    expect(find.text('表达边界'), findsOneWidget);
    expect(find.text('校园故事 / 室友互损 / 嘴硬心软'), findsNWidgets(2));
    expect(
      tester.getSize(find.byKey(const Key('role-profile-summary'))).height,
      90,
    );
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_ROLE_PROFILE')) {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/popi-role-profile.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('reopening the same role fetches fresh details every time', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpPage(
      tester,
      load: (id) async {
        calls.add(id);
        return LibraryRole(
          id: id,
          title: 'Latest ${calls.length}',
          description: 'Fresh details',
        );
      },
    );
    expect(calls, ['7']);
    expect(find.text('Latest 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('role-profile-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(calls, ['7', '7']);
    expect(find.text('Latest 2'), findsOneWidget);
    expect(find.text('Latest 1'), findsNothing);
  });

  testWidgets('official roles have no management permissions', (tester) async {
    await pumpPage(
      tester,
      category: 'official',
      load: (_) async => const LibraryRole(
        id: '7',
        title: 'Official role',
        description: '',
        canEdit: true,
      ),
    );
    expect(find.byKey(const Key('role-delete')), findsNothing);
    expect(find.byKey(const Key('role-improve')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('role-create')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('role-create')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SessionPage>(find.byType(SessionPage)).initialPrompt,
      contains('Official role'),
    );
  });

  testWidgets('failed details can retry and actions wait for permissions', (
    tester,
  ) async {
    var calls = 0;
    await pumpPage(
      tester,
      load: (_) async {
        if (++calls == 1) throw StateError('Offline');
        return sample;
      },
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('role-create')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('加载失败，点击重试'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('role-create')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'editable role archive has no delete button and full-width actions',
    (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const Key('role-delete')), findsNothing);
      expect(find.text('删除'), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('role-improve'))).width,
        tester.getSize(find.byKey(const Key('role-create'))).width,
      );
    },
  );

  testWidgets('actions stay fixed while a long profile scrolls', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(390, 844),
      load: (_) async => LibraryRole(
        id: '7',
        title: 'Long profile',
        description: List.filled(30, 'Long character description.').join(' '),
        canEdit: true,
        canCreate: true,
      ),
    );
    final actions = find.byKey(const Key('role-profile-actions'));
    final before = tester.getRect(actions);
    expect(before.bottom, lessThanOrEqualTo(824));
    await tester.drag(
      find.byKey(const Key('role-profile-scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(actions), before);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('role-improve')))
          .onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('role-delete')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creative action carries the role into the existing composer', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('role-create')));
    await tester.tap(find.byKey(const Key('role-create')));
    await tester.pumpAndSettle();
    final home = tester.widget<SessionPage>(find.byType(SessionPage));
    expect(home.initialPrompt, contains('爱丽丝'));
    expect(home.initialPrompt, contains('ID: 7'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screens and larger English text remain scrollable', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(320, 640),
      locale: const Locale('en'),
      textScale: 1.3,
    );
    await tester.ensureVisible(find.byKey(const Key('role-create')));
    await tester.pumpAndSettle();
    expect(find.text('Create with this role'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
