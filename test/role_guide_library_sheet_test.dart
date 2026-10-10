import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_guide_picker.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_guide_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_skeleton.dart';

import 'support/role_library_fixtures.dart';

List<LibraryRole> roles(int start, int count) => [
  for (var id = start; id < start + count; id++)
    LibraryRole(id: '$id', title: 'Role $id', description: 'Description $id'),
];

Future<void> pumpSheet(
  WidgetTester tester,
  RolePageLoader loader, {
  Size size = const Size(440, 956),
  Locale locale = const Locale('zh'),
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final selected = <LibraryRole>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(roleLibraryDio(loadPage: loader)),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RoleGuideSheet(
              title: 'Library',
              builder: (_, controller) => RoleGuidePicker(
                fullLibrary: true,
                scrollController: controller,
                selected: () => selected,
                onToggle: (role) {
                  if (selected.any((item) => item.id == role.id)) {
                    selected.removeWhere((item) => item.id == role.id);
                  } else {
                    selected.add(role);
                  }
                },
                onDetails: (_) {},
                onCreate: () {},
                onCategoryChanged: (_) {},
              ),
              footer: const SizedBox(height: 40),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

ScrollController scrollController(WidgetTester tester) => tester
    .widget<ListView>(find.byKey(const Key('role-guide-library-scroll')))
    .controller!;

void main() {
  testWidgets('initial skeleton is replaced by retry and then an empty state', (
    tester,
  ) async {
    final pending = Completer<LibraryRolePage>();
    final requests = <int>[];
    await pumpSheet(tester, ({
      required category,
      required page,
      required pageSize,
    }) {
      requests.add(page);
      return requests.length == 1
          ? pending.future
          : Future.value(
              LibraryRolePage(items: const [], page: 1, pageCount: 1),
            );
    });
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('role-guide-library-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(AppSkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pending.completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-guide-library-skeleton')), findsNothing);
    await tester.tap(find.byKey(const Key('role-guide-retry')));
    await tester.pumpAndSettle();
    expect(requests, [1, 1]);
    expect(find.text('暂无官方角色'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrolling appends one page and keeps selections without duplicates',
    (tester) async {
      final pending = Completer<LibraryRolePage>();
      final requests = <int>[];
      final pageSizes = <int>[];
      await pumpSheet(tester, ({
        required category,
        required page,
        required pageSize,
      }) {
        requests.add(page);
        pageSizes.add(pageSize);
        return page == 1
            ? Future.value(
                LibraryRolePage(items: roles(1, 20), page: 1, pageCount: 2),
              )
            : pending.future;
      });
      await tester.pumpAndSettle();
      expect(requests, [1]);
      await tester.tap(find.byKey(const Key('role-library-select-1')));
      await tester.pumpAndSettle();
      final controller = scrollController(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(requests, [1, 2]);
      expect(pageSizes, [20, 20]);
      await tester.scrollUntilVisible(
        find.byKey(const Key('role-guide-library-loading-more')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('role-guide-library-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('role-guide-library-loading-more')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('role-library-select-20')), findsOneWidget);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(requests, [1, 2]);
      pending.complete(
        LibraryRolePage(items: roles(20, 2), page: 2, pageCount: 2),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role-library-select-20')), findsOneWidget);
      expect(find.byKey(const Key('role-library-select-21')), findsOneWidget);
      expect(find.text('已加载全部角色'), findsOneWidget);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(requests, [1, 2]);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      final selection = find.ancestor(
        of: find.byKey(const Key('role-library-select-1')),
        matching: find.byType(Semantics),
      );
      expect(
        tester.widget<Semantics>(selection.first).properties.selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed pagination keeps rows and retries the same page', (
    tester,
  ) async {
    var attempts = 0;
    final requests = <int>[];
    await pumpSheet(tester, ({
      required category,
      required page,
      required pageSize,
    }) async {
      requests.add(page);
      if (page == 2 && ++attempts == 1) throw StateError('Offline');
      return LibraryRolePage(
        items: page == 1 ? roles(1, 20) : roles(21, 1),
        page: page,
        pageCount: 2,
      );
    });
    await tester.pumpAndSettle();
    final controller = scrollController(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-library-select-20')), findsOneWidget);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(requests, [1, 2]);
    await tester.tap(find.byKey(const Key('role-guide-retry')));
    await tester.pumpAndSettle();
    expect(requests, [1, 2, 2]);
    expect(find.byKey(const Key('role-library-select-21')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category changes reset scrolling and ignore a late next page', (
    tester,
  ) async {
    final pending = Completer<LibraryRolePage>();
    await pumpSheet(tester, ({
      required category,
      required page,
      required pageSize,
    }) async {
      if (category == 'personal') {
        return LibraryRolePage(items: roles(100, 1), page: 1, pageCount: 1);
      }
      if (page == 2) return pending.future;
      return LibraryRolePage(items: roles(1, 20), page: 1, pageCount: 2);
    });
    await tester.pumpAndSettle();
    final controller = scrollController(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-segment-1')));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    pending.complete(
      LibraryRolePage(items: roles(21, 1), page: 2, pageCount: 2),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-library-select-100')), findsOneWidget);
    expect(find.byKey(const Key('role-library-select-21')), findsNothing);
    expect(
      find.byKey(const Key('role-guide-library-loading-more')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
      'English dark skeleton fits $size and disposes during loading',
      (tester) async {
        final pending = Completer<LibraryRolePage>();
        await pumpSheet(
          tester,
          ({required category, required page, required pageSize}) =>
              pending.future,
          size: size,
          locale: const Locale('en'),
          dark: true,
        );
        expect(find.byType(AppSkeletonList), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        pending.complete(
          LibraryRolePage(items: roles(1, 1), page: 1, pageCount: 1),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
