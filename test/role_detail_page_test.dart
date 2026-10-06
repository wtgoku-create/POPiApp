import 'dart:io';
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
import 'package:popi_ai_app/features/assets/presentation/role_detail_page.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

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
      'boundaries': {'label': '表达边界', 'value': '保持角色外形、配色和行为逻辑一致。不通过伤害他人推进故事。'}
    },
  },
);

void main() {
  final boundaryKey = GlobalKey();
  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    String category = 'personal',
    Locale locale = const Locale('zh'),
    double textScale = 1,
    Future<LibraryRole> Function(String)? load,
    Future<void> Function(String)? delete,
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
            File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)));
        await loader.load();
      });
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'ProfileCapture'),
        primaryTextTheme:
            theme.primaryTextTheme.apply(fontFamily: 'ProfileCapture'),
      );
    }
    await tester.pumpWidget(ProviderScope(
      overrides: [
        roleDetailLoaderProvider.overrideWithValue(load ?? (_) async => sample),
        roleDeleteProvider.overrideWithValue(delete ?? (_) async {}),
      ],
      child: MaterialApp(
        theme: theme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(key: boundaryKey, child: child!),
        ),
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                          builder: (_) => RoleDetailPage(
                              role: sample, category: category))),
                  child: const Text('Open'),
                ))),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  test('detail and deletion use the Web studio contracts', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      handler.resolve(Response(requestOptions: request, data: {
        'data': request.method == 'DELETE'
            ? {}
            : {
                'id': 7,
                'canEdit': true,
                'canUseText': true,
                'isCertified': true,
                'profileVersion': {
                  'profile': {'title': 'Current', 'targetAudience': 'Audience'}
                },
              },
      }));
    }));
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

  testWidgets('renders the archive and actions from real profile fields',
      (tester) async {
    await pumpPage(tester);
    expect(find.text('角色档案'), findsOneWidget);
    expect(find.text('表达边界'), findsOneWidget);
    expect(find.text('校园故事 / 室友互损 / 嘴硬心软'), findsNWidgets(2));
    expect(tester.getSize(find.byKey(const Key('role-profile-summary'))).height,
        90);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_ROLE_PROFILE')) {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/popi-role-profile.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('reopening the same role fetches fresh details every time',
      (tester) async {
    final calls = <String>[];
    await pumpPage(tester, load: (id) async {
      calls.add(id);
      return LibraryRole(
          id: id,
          title: 'Latest ${calls.length}',
          description: 'Fresh details');
    });
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
    await pumpPage(tester,
        category: 'official',
        load: (_) async => const LibraryRole(
            id: '7', title: 'Official role', description: '', canEdit: true));
    expect(find.byKey(const Key('role-delete')), findsNothing);
    expect(find.byKey(const Key('role-improve')), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('role-create')))
            .onPressed,
        isNotNull);
    await tester.tap(find.byKey(const Key('role-create')));
    await tester.pumpAndSettle();
    expect(tester.widget<HomePage>(find.byType(HomePage)).initialPrompt,
        contains('Official role'));
  });

  testWidgets('failed details can retry and actions wait for permissions',
      (tester) async {
    var calls = 0;
    await pumpPage(tester, load: (_) async {
      if (++calls == 1) throw StateError('Offline');
      return sample;
    });
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('role-create')))
            .onPressed,
        isNull);
    await tester.tap(find.text('加载失败，点击重试'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('role-create')))
            .onPressed,
        isNotNull);
  });

  testWidgets('deletion requires confirmation and returns to the list',
      (tester) async {
    final deleted = <String>[];
    await pumpPage(tester, delete: (id) async => deleted.add(id));
    await tester.ensureVisible(find.byKey(const Key('role-delete')));
    await tester.tap(find.byKey(const Key('role-delete')));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.text('删除后，该角色将不会再出现在个人和社区角色库中，且无法恢复。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.byKey(const Key('role-detail-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('role-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-role')));
    await tester.pumpAndSettle();
    expect(deleted, ['7']);
    expect(find.byKey(const Key('role-detail-page')), findsNothing);
  });

  testWidgets('actions stay fixed while a long profile scrolls',
      (tester) async {
    await pumpPage(tester,
        size: const Size(390, 844),
        load: (_) async => LibraryRole(
              id: '7',
              title: 'Long profile',
              description:
                  List.filled(30, 'Long character description.').join(' '),
              canEdit: true,
              canCreate: true,
            ));
    final actions = find.byKey(const Key('role-profile-actions'));
    final before = tester.getRect(actions);
    expect(before.bottom, lessThanOrEqualTo(824));
    await tester.drag(
        find.byKey(const Key('role-profile-scroll')), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(actions), before);
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('role-delete')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creative action carries the role into the existing composer',
      (tester) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('role-create')));
    await tester.tap(find.byKey(const Key('role-create')));
    await tester.pumpAndSettle();
    final home = tester.widget<HomePage>(find.byType(HomePage));
    expect(home.initialPrompt, contains('爱丽丝'));
    expect(home.initialPrompt, contains('ID: 7'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screens and larger English text remain scrollable',
      (tester) async {
    await pumpPage(tester,
        size: const Size(320, 640), locale: const Locale('en'), textScale: 1.3);
    await tester.ensureVisible(find.byKey(const Key('role-create')));
    await tester.pumpAndSettle();
    expect(find.text('Create with this role'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
