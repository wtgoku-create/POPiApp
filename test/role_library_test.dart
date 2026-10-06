import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/assets/data/role_library_repository.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/assets/presentation/role_library_list.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

LibraryRole role(int id) =>
    LibraryRole(id: '$id', title: 'Role $id', description: 'Description $id');

void main() {
  Future<ValueNotifier<String>> pumpRoles(
      WidgetTester tester, RolePageLoader loader) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final category = ValueNotifier('official');
    addTearDown(category.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        rolePageLoaderProvider.overrideWithValue(loader),
        roleDetailLoaderProvider
            .overrideWithValue((id) async => role(int.parse(id))),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
            body: ValueListenableBuilder<String>(
                valueListenable: category,
                builder: (_, category, __) =>
                    RoleLibraryList(category: category))),
      ),
    ));
    await tester.pump();
    return category;
  }

  test('matches studio role endpoint and page envelope', () async {
    final dio = Dio();
    late RequestOptions request;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      request = options;
      handler.resolve(Response(requestOptions: options, data: {
        'requestId': 'request',
        'data': {
          'list': [
            {
              'id': 7,
              'title': 'Old title',
              'description': '',
              'profileVersion': {
                'profile': {
                  'title': 'Current title',
                  'appearance': 'Appearance'
                }
              },
              'avatar': 'https://example.com/avatar.png'
            }
          ],
          'pageInfo': {'page': 2, 'pageSize': 20, 'pageCount': 3, 'total': 42},
        },
      }));
    }));
    final result = LibraryRolePage.fromJson(await NetworkApi(dio)
        .listLibraryRoles(category: 'personal', page: 2, pageSize: 20));
    expect(request.path, '/api_client/agent/v2/roles');
    expect(request.queryParameters,
        {'category': 'personal', 'page': 2, 'pageSize': 20});
    expect(result.items.single.id, '7');
    expect(result.items.single.title, 'Current title');
    expect(result.items.single.description, 'Appearance');
    expect(result.hasMore, isTrue);
  });

  testWidgets('loads more, deduplicates and refreshes from page one',
      (tester) async {
    final calls = <int>[];
    await pumpRoles(tester, (
        {required category, required page, required pageSize}) async {
      calls.add(page);
      return LibraryRolePage(
          items: page == 1 ? List.generate(8, role) : [role(7), role(8)],
          page: page,
          pageCount: 2);
    });
    await tester.pumpAndSettle();
    expect(calls, [1]);
    expect(tester.getSize(find.byKey(const Key('assets-role-0'))).height, 90);
    await tester.drag(
        find.byKey(const Key('assets-roles-grid')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(calls, [1, 2]);
    expect(find.text('Role 8'), findsOneWidget);
    expect(find.text('Role 7'), findsOneWidget);
    expect(find.text('已加载全部角色'), findsOneWidget);
    final scroll = tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const Key('assets-roles-grid')),
        matching: find.byType(Scrollable)));
    scroll.position.jumpTo(0);
    await tester.pump();
    await tester.drag(
        find.byKey(const Key('assets-roles-grid')), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(calls.last, 1);
    expect(find.text('Role 0'), findsOneWidget);
  });

  testWidgets('page failure retains roles and retries the same page',
      (tester) async {
    final calls = <int>[];
    var failedOnce = false;
    await pumpRoles(tester, (
        {required category, required page, required pageSize}) async {
      calls.add(page);
      if (page == 2 && !failedOnce) {
        failedOnce = true;
        throw StateError('Offline');
      }
      return LibraryRolePage(
          items: page == 1 ? List.generate(8, role) : [role(8)],
          page: page,
          pageCount: 2);
    });
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const Key('assets-roles-grid')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Role 7'), findsOneWidget);
    expect(find.byKey(const Key('roles-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('roles-retry')));
    await tester.pumpAndSettle();
    expect(calls, [1, 2, 2]);
    expect(find.text('Role 8'), findsOneWidget);
  });

  testWidgets('ignores old category responses', (tester) async {
    final old = Completer<LibraryRolePage>();
    final categories = <String>[];
    final category = await pumpRoles(tester, (
        {required category, required page, required pageSize}) {
      categories.add(category);
      return category == 'official'
          ? old.future
          : Future.value(
              LibraryRolePage(items: [role(99)], page: 1, pageCount: 1));
    });
    category.value = 'personal';
    await tester.pumpAndSettle();
    old.complete(LibraryRolePage(items: [role(1)], page: 1, pageCount: 1));
    await tester.pumpAndSettle();
    expect(categories, ['official', 'personal']);
    expect(find.text('Role 99'), findsOneWidget);
    expect(find.text('Role 1'), findsNothing);
    await tester.tap(find.text('Role 99'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-detail-page')), findsOneWidget);
    expect(find.text('Description 99'), findsWidgets);
    await tester.tap(find.byKey(const Key('role-profile-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-detail-page')), findsNothing);
    expect(find.text('Role 99'), findsOneWidget);
    expect(categories, ['official', 'personal']);
  });

  testWidgets('empty and failed lists remain refreshable', (tester) async {
    var calls = 0;
    await pumpRoles(tester, (
        {required category, required page, required pageSize}) async {
      if (++calls == 1) throw StateError('Offline');
      return const LibraryRolePage(items: [], page: 1, pageCount: 0);
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roles-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('roles-retry')));
    await tester.pumpAndSettle();
    expect(find.text('暂无官方角色'), findsOneWidget);
    await tester.drag(
        find.byKey(const Key('assets-roles-grid')), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(calls, 3);
  });

  testWidgets('personal empty state matches the design and remains refreshable',
      (tester) async {
    final calls = <String>[];
    final category = await pumpRoles(tester, (
        {required category, required page, required pageSize}) async {
      calls.add(category);
      return const LibraryRolePage(items: [], page: 1, pageCount: 0);
    });
    category.value = 'personal';
    tester.view.physicalSize = const Size(320, 500);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-roles-empty-state')), findsOneWidget);
    expect(find.text('暂无角色'), findsOneWidget);
    expect(find.text('创建角色作为人物资产丰富视频'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
        find.byKey(const Key('assets-roles-grid')), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(calls, ['official', 'personal', 'personal']);
    await tester.tap(find.byKey(const Key('my-roles-create')));
    await tester.pumpAndSettle();
    expect(tester.widget<HomePage>(find.byType(HomePage)).initialPrompt,
        contains('新角色'));
  });
}
