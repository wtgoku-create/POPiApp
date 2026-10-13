import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/widgets/ip_account_roles_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/ip_account_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';

import 'support/ip_account_fixtures.dart';

class _RolesUserController extends UserController {
  @override
  User? build() => const User(id: 'user', name: 'User', email: '');
}

class _RolesRepository extends FixtureIpAccountRepository {
  final requests = <String>[];
  bool fail = false;

  @override
  Future<List<LibraryRole>> availableRoles(
    String category, {
    CancelToken? cancelToken,
  }) async {
    requests.add(category);
    if (fail) throw StateError('Role loading failed');
    return [
      for (var index = 0; index < 180; index++)
        LibraryRole(
          id: '$category-$index',
          title: '$category role $index',
          description: index.isEven
              ? 'A longer description that wraps on narrow screens and '
                    'keeps the role row height dynamic.'
              : '',
        ),
    ];
  }
}

void main() {
  late _RolesRepository repository;
  late List<({List<String> ids, String requestId})> saves;
  late bool failSave;
  setUp(() {
    repository = _RolesRepository();
    saves = [];
    failSave = false;
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    List<String> selectedIds = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(_RolesUserController.new),
        ipAccountRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => IconButton(
                key: const Key('open-role-sheet'),
                icon: const Icon(Icons.group),
                onPressed: () => AppSheet.show<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => IpAccountRolesSheet(
                    selectedIds: selectedIds,
                    selectedNames: {
                      for (final id in selectedIds) id: 'Selected $id',
                    },
                    onSave: (ids, requestId) async {
                      saves.add((ids: ids, requestId: requestId));
                      if (failSave) throw StateError('Saving failed');
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-role-sheet')));
    await tester.pumpAndSettle();
  }

  Finder role(String id) => find.byKey(Key('ip-account-select-role-$id'));
  Finder roleScroll() => find.descendant(
    of: find.byKey(const Key('ip-account-roles-list')),
    matching: find.byType(Scrollable),
  );

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets(
      'long role list builds on demand and retains choices at $size',
      (tester) async {
        await pumpSheet(tester, size: size);
        final first = role('user-0');
        final last = role('user-179');
        expect(first, findsOneWidget);
        expect(last, findsNothing);
        expect(find.byType(CheckboxListTile).evaluate().length, lessThan(30));
        await tester.tap(first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(last, 500, scrollable: roleScroll());
        await tester.pumpAndSettle();
        expect(first, findsNothing);
        await tester.tap(last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(first, -500, scrollable: roleScroll());
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(first).value, isTrue);
        expect(find.byType(CheckboxListTile).evaluate().length, lessThan(30));

        await tester.tap(find.text('Official roles'));
        await tester.pumpAndSettle();
        await tester.tap(role('official-0'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('My roles'));
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(first).value, isTrue);
        await tester.tap(find.byKey(const Key('ip-account-roles-save')));
        await tester.pumpAndSettle();
        expect(saves.single.ids, ['user-0', 'user-179', 'official-0']);
        expect(repository.requests, ['user', 'official', 'user']);
        expect(find.byType(IpAccountRolesSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('role limit disables new choices and chip removal releases it', (
    tester,
  ) async {
    final selected = List.generate(20, (index) => 'user-$index');
    await pumpSheet(tester, selectedIds: selected);
    expect(find.text('Add up to 20 roles'), findsOneWidget);
    final extra = role('user-20');
    await tester.scrollUntilVisible(extra, 300, scrollable: roleScroll());
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(extra).onChanged, isNull);
    final chip = find.widgetWithText(InputChip, 'Selected user-0');
    final remove = find.descendant(
      of: chip,
      matching: find.byTooltip('Delete'),
    );
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Add up to 20 roles'), findsNothing);
    expect(tester.widget<CheckboxListTile>(extra).onChanged, isNotNull);
    await tester.tap(extra);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ip-account-roles-save')));
    await tester.pumpAndSettle();
    expect(saves.single.ids, [...selected.skip(1), 'user-20']);
    expect(saves.single.ids, hasLength(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed saving keeps choices and reuses the request ID', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.tap(role('user-0'));
    await tester.pumpAndSettle();
    failSave = true;
    await tester.tap(find.byKey(const Key('ip-account-roles-save')));
    await tester.pumpAndSettle();
    expect(find.byType(IpAccountRolesSheet), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(role('user-0')).value, isTrue);
    failSave = false;
    await tester.tap(find.byKey(const Key('ip-account-roles-save')));
    await tester.pumpAndSettle();
    expect(saves, hasLength(2));
    expect(saves.last.ids, ['user-0']);
    expect(saves.last.requestId, saves.first.requestId);
    expect(find.byType(IpAccountRolesSheet), findsNothing);
  });

  testWidgets('role loading failure can retry', (tester) async {
    repository.fail = true;
    await pumpSheet(tester);
    expect(find.byType(CheckboxListTile), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(role('user-0'), findsOneWidget);
    expect(repository.requests, ['user', 'user']);
    expect(tester.takeException(), isNull);
  });
}
