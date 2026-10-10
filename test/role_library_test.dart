import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/assets/presentation/role_library_list.dart';
import 'package:popi_ai_app/features/assets/presentation/role_detail_page.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

import 'support/role_library_fixtures.dart';

LibraryRole role(int id, {bool canEdit = false}) => LibraryRole(
  id: '$id',
  title: 'Role $id',
  description: 'Description $id',
  canEdit: canEdit,
);

void main() {
  Future<ValueNotifier<String>> pumpRoles(
    WidgetTester tester,
    RolePageLoader loader, {
    String initialCategory = 'official',
    Future<void> Function(String)? delete,
  }) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final category = ValueNotifier(initialCategory);
    addTearDown(category.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: category,
              builder: (_, category, __) => RoleLibraryList(category: category),
            ),
          ),
        ),
        GoRoute(
          path: '/session',
          builder: (_, state) =>
              SessionPage(initialPrompt: state.uri.queryParameters['prompt']),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
            roleLibraryDio(
              loadPage: loader,
              delete: delete,
              loadDetail: (id) async => role(int.parse(id)),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    return category;
  }

  Future<void> revealDelete(WidgetTester tester, int id) async {
    await tester.drag(
      find
          .ancestor(
            of: find.byKey(Key('assets-role-$id')),
            matching: find.byType(Slidable),
          )
          .first,
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reopening the role library requests fresh data', (tester) async {
    var requests = 0;
    Future<LibraryRolePage> load({
      required String category,
      required int page,
      required int pageSize,
    }) async =>
        LibraryRolePage(items: [role(++requests)], page: page, pageCount: 1);
    await pumpRoles(tester, load);
    await tester.pumpAndSettle();
    expect(find.text('Role 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpRoles(tester, load);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Role 2'), findsOneWidget);
    expect(find.text('Role 1'), findsNothing);
  });

  testWidgets(
    'empty role loading uses skeletons and keeps rows during refresh',
    (tester) async {
      var pending = Completer<LibraryRolePage>();
      await pumpRoles(
        tester,
        ({required category, required page, required pageSize}) =>
            pending.future,
      );
      expect(find.byKey(const Key('roles-skeleton')), findsOneWidget);
      expect(find.text('暂无官方角色'), findsNothing);
      pending.complete(
        LibraryRolePage(items: [role(1)], page: 1, pageCount: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('roles-skeleton')), findsNothing);
      expect(find.text('Role 1'), findsOneWidget);
      pending = Completer<LibraryRolePage>();
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final loading = refresh.onRefresh();
      await tester.pump();
      expect(find.text('Role 1'), findsOneWidget);
      expect(find.byKey(const Key('roles-skeleton')), findsNothing);
      pending.complete(
        LibraryRolePage(items: [role(2)], page: 1, pageCount: 1),
      );
      await tester.pumpAndSettle();
      await loading;
      expect(find.text('Role 1'), findsNothing);
      expect(find.text('Role 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty role refresh shows skeletons until completion', (
    tester,
  ) async {
    var pending = Future.value(
      const LibraryRolePage(items: [], page: 1, pageCount: 0),
    );
    await pumpRoles(
      tester,
      ({required category, required page, required pageSize}) => pending,
    );
    await tester.pumpAndSettle();
    final completer = Completer<LibraryRolePage>();
    pending = completer.future;
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final loading = refresh.onRefresh();
    await tester.pump();
    expect(find.byKey(const Key('roles-skeleton')), findsOneWidget);
    expect(find.text('暂无官方角色'), findsNothing);
    completer.complete(const LibraryRolePage(items: [], page: 1, pageCount: 0));
    await tester.pumpAndSettle();
    await loading;
    expect(find.byKey(const Key('roles-skeleton')), findsNothing);
    expect(find.text('暂无官方角色'), findsOneWidget);
  });

  testWidgets(
    'swipe reveals deletion, cancel retains row, confirm refreshes list',
    (tester) async {
      final roles = [role(1, canEdit: true), role(2, canEdit: true)];
      final deleted = <String>[];
      final pages = <int>[];
      await pumpRoles(
        tester,
        ({required category, required page, required pageSize}) async {
          pages.add(page);
          return LibraryRolePage(items: List.of(roles), page: 1, pageCount: 1);
        },
        initialCategory: 'personal',
        delete: (id) async {
          deleted.add(id);
          roles.removeWhere((role) => role.id == id);
        },
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('role-list-delete-1')).hitTestable();
      expect(action, findsNothing);
      await revealDelete(tester, 1);
      expect(action, findsOneWidget);
      expect(deleted, isEmpty);
      expect(find.byKey(const Key('role-detail-page')), findsNothing);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('删除后，该角色将不会再出现在个人和社区角色库中，且无法恢复。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      expect(find.text('Role 1'), findsOneWidget);
      await revealDelete(tester, 1);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-role')));
      await tester.pumpAndSettle();
      expect(deleted, ['1']);
      expect(find.text('Role 1'), findsNothing);
      expect(find.text('Role 2'), findsOneWidget);
      expect(pages, [1, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('official and noneditable roles have no swipe deletion', (
    tester,
  ) async {
    final category = await pumpRoles(
      tester,
      ({required category, required page, required pageSize}) async =>
          LibraryRolePage(
            items: [role(1, canEdit: category == 'official')],
            page: 1,
            pageCount: 1,
          ),
    );
    await tester.pumpAndSettle();
    await revealDelete(tester, 1);
    expect(
      find.byKey(const Key('role-list-delete-1')).hitTestable(),
      findsNothing,
    );
    category.value = 'personal';
    await tester.pumpAndSettle();
    await revealDelete(tester, 1);
    expect(
      find.byKey(const Key('role-list-delete-1')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.text('Role 1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-detail-page')), findsOneWidget);
  });

  testWidgets('opening another swipe action closes the previous row', (
    tester,
  ) async {
    await pumpRoles(
      tester,
      ({required category, required page, required pageSize}) async =>
          LibraryRolePage(
            items: [role(1, canEdit: true), role(2, canEdit: true)],
            page: 1,
            pageCount: 1,
          ),
      initialCategory: 'personal',
    );
    await tester.pumpAndSettle();
    await revealDelete(tester, 1);
    expect(
      find.byKey(const Key('role-list-delete-1')).hitTestable(),
      findsOneWidget,
    );
    await revealDelete(tester, 2);
    expect(
      find.byKey(const Key('role-list-delete-1')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const Key('role-list-delete-2')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending deletion blocks other actions and failure preserves rows',
    (tester) async {
      final pending = Completer<void>();
      final calls = <String>[];
      await pumpRoles(
        tester,
        ({required category, required page, required pageSize}) async =>
            LibraryRolePage(
              items: [role(1, canEdit: true), role(2, canEdit: true)],
              page: 1,
              pageCount: 1,
            ),
        initialCategory: 'personal',
        delete: (id) {
          calls.add(id);
          return pending.future;
        },
      );
      await tester.pumpAndSettle();
      await revealDelete(tester, 1);
      await tester.tap(
        find.byKey(const Key('role-list-delete-1')).hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-role')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.drag(
        find
            .ancestor(
              of: find.byKey(const Key('assets-role-2')),
              matching: find.byType(Slidable),
            )
            .first,
        const Offset(-180, 0),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(const Key('role-list-delete-2')).hitTestable(),
        findsNothing,
      );
      expect(calls, ['1']);
      pending.completeError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(find.text('Role 1'), findsOneWidget);
      expect(find.text('Role 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await revealDelete(tester, 1);
      expect(
        find.byKey(const Key('role-list-delete-1')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing category during confirmation cancels the pending delete',
    (tester) async {
      final deleted = <String>[];
      final category = await pumpRoles(
        tester,
        ({required category, required page, required pageSize}) async =>
            LibraryRolePage(
              items: [role(1, canEdit: true)],
              page: 1,
              pageCount: 1,
            ),
        initialCategory: 'personal',
        delete: (id) async => deleted.add(id),
      );
      await tester.pumpAndSettle();
      await revealDelete(tester, 1);
      await tester.tap(
        find.byKey(const Key('role-list-delete-1')).hitTestable(),
      );
      await tester.pumpAndSettle();
      category.value = 'official';
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-role')));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      expect(find.text('Role 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('matches studio role endpoint and page envelope', () async {
    final dio = Dio();
    late RequestOptions request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
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
                          'appearance': 'Appearance',
                        },
                      },
                      'avatar': 'https://example.com/avatar.png',
                    },
                  ],
                  'pageInfo': {
                    'page': 2,
                    'pageSize': 20,
                    'pageCount': 3,
                    'total': 42,
                  },
                },
              },
            ),
          );
        },
      ),
    );
    final result = LibraryRolePage.fromJson(
      await NetworkApi(
        dio,
      ).listLibraryRoles(category: 'personal', page: 2, pageSize: 20),
    );
    expect(request.path, '/api_client/agent/v2/roles');
    expect(request.queryParameters, {
      'category': 'personal',
      'page': 2,
      'pageSize': 20,
    });
    expect(result.items.single.id, '7');
    expect(result.items.single.title, 'Current title');
    expect(result.items.single.description, 'Appearance');
    expect(result.hasMore, isTrue);
  });

  testWidgets('loads more, deduplicates and refreshes from page one', (
    tester,
  ) async {
    final calls = <int>[];
    await pumpRoles(tester, ({
      required category,
      required page,
      required pageSize,
    }) async {
      calls.add(page);
      return LibraryRolePage(
        items: page == 1 ? List.generate(8, role) : [role(7), role(8)],
        page: page,
        pageCount: 2,
      );
    });
    await tester.pumpAndSettle();
    expect(calls, [1]);
    expect(tester.getSize(find.byKey(const Key('assets-role-0'))).height, 90);
    await tester.drag(
      find.byKey(const Key('assets-roles-grid')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(calls, [1, 2]);
    expect(find.text('Role 8'), findsOneWidget);
    expect(find.text('Role 7'), findsOneWidget);
    expect(find.text('已加载全部角色'), findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('assets-roles-grid')),
        matching: find.byType(Scrollable),
      ),
    );
    scroll.position.jumpTo(0);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('assets-roles-grid')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(calls.last, 1);
    expect(find.text('Role 0'), findsOneWidget);
  });

  testWidgets('page failure retains roles and retries the same page', (
    tester,
  ) async {
    final calls = <int>[];
    var failedOnce = false;
    await pumpRoles(tester, ({
      required category,
      required page,
      required pageSize,
    }) async {
      calls.add(page);
      if (page == 2 && !failedOnce) {
        failedOnce = true;
        throw StateError('Offline');
      }
      return LibraryRolePage(
        items: page == 1 ? List.generate(8, role) : [role(8)],
        page: page,
        pageCount: 2,
      );
    });
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('assets-roles-grid')),
      const Offset(0, -600),
    );
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
    final category = await pumpRoles(tester, ({
      required category,
      required page,
      required pageSize,
    }) {
      categories.add(category);
      return category == 'official'
          ? old.future
          : Future.value(
              LibraryRolePage(items: [role(99)], page: 1, pageCount: 1),
            );
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
    expect(
      tester.widget<RoleDetailPage>(find.byType(RoleDetailPage)).role.id,
      '99',
    );
    expect(find.byKey(const Key('role-profile-archive')), findsNothing);
    await tester.tap(find.byKey(const Key('role-profile-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-detail-page')), findsNothing);
    expect(find.text('Role 99'), findsOneWidget);
    expect(categories, ['official', 'personal']);
  });

  testWidgets('empty and failed lists remain refreshable', (tester) async {
    var calls = 0;
    await pumpRoles(tester, ({
      required category,
      required page,
      required pageSize,
    }) async {
      if (++calls == 1) throw StateError('Offline');
      return const LibraryRolePage(items: [], page: 1, pageCount: 0);
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roles-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('roles-retry')));
    await tester.pumpAndSettle();
    expect(find.text('暂无官方角色'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('assets-roles-grid')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(calls, 3);
  });

  testWidgets(
    'personal empty state matches the design and remains refreshable',
    (tester) async {
      final calls = <String>[];
      final category = await pumpRoles(tester, ({
        required category,
        required page,
        required pageSize,
      }) async {
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
        find.byKey(const Key('assets-roles-grid')),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(calls, ['official', 'personal', 'personal']);
      await tester.tap(find.byKey(const Key('my-roles-create')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SessionPage>(find.byType(SessionPage)).initialPrompt,
        contains('新角色'),
      );
      await tester.tap(find.byKey(const Key('popi-open-navigation')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popi-navigation-drawer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
