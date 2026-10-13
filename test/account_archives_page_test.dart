import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/account_preferences.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account_home.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/account_archives_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/ip_account_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/ip_account_fixtures.dart';

class _ArchiveUserController extends UserController {
  @override
  User? build() => const User(id: 'user', name: 'User', email: '');
}

class _ArchiveRepository extends FixtureIpAccountRepository {
  int archivePageSize = 20;
  bool failHistory = false;
  final historyPages = <int>[];
  final historyKeywords = <String>[];
  final detailRequests = <(String, String, String?)>[];

  @override
  Future<AccountArchivePage> archives(
    String id, {
    String keyword = '',
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    historyPages.add(page);
    historyKeywords.add(keyword);
    if (failHistory) throw StateError('Failed');
    final matching = creations
        .where(
          (item) => item.title.toLowerCase().contains(keyword.toLowerCase()),
        )
        .toList();
    return AccountArchivePage(
      items: matching
          .skip((page - 1) * archivePageSize)
          .take(archivePageSize)
          .toList(),
      page: page,
      pageCount: (matching.length / archivePageSize).ceil(),
      total: matching.length,
    );
  }

  @override
  Future<AccountCreationArchive> archiveDetail(
    String id,
    String creationId, {
    String? versionId,
    CancelToken? cancelToken,
  }) async {
    detailRequests.add((id, creationId, versionId));
    return AccountCreationArchive(
      title: 'Archive detail',
      sections: const {'script': 'Archived script'},
      versions: const {},
      versionId: versionId,
    );
  }
}

void main() {
  late _ArchiveRepository repository;
  setUp(() => repository = _ArchiveRepository());

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(440, 956),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(_ArchiveUserController.new),
        ipAccountRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openArchives(WidgetTester tester) async {
    unawaited(
      Navigator.of(tester.element(find.byType(Scaffold))).push<void>(
        MaterialPageRoute(
          builder: (_) => const AccountArchivesPage(accountId: '42'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets(
      'long archives build on demand and open the right detail at $size',
      (tester) async {
        repository.archivePageSize = 180;
        repository.creations = [
          for (var index = 0; index < 180; index++)
            IpAccountCreation(
              id: '$index',
              title: 'Archive $index',
              summary: index.isEven
                  ? 'A longer archive summary that wraps on narrow screens '
                        'and keeps the row height dynamic.'
                  : '',
              versionId: 'version-$index',
            ),
        ];
        await pump(tester, size: size);
        await openArchives(tester);
        final first = find.byKey(const ValueKey('archive-0'));
        final last = find.byKey(const ValueKey('archive-179'));
        final rows = find.descendant(
          of: find.byKey(const Key('account-archive-list')),
          matching: find.byType(ListTile),
        );
        expect(first, findsOneWidget);
        expect(last, findsNothing);
        expect(rows.evaluate().length, lessThan(30));
        final scrollable = find.descendant(
          of: find.byKey(const Key('account-archive-list')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(last, 500, scrollable: scrollable);
        await tester.pumpAndSettle();
        expect(first, findsNothing);
        expect(last.hitTestable(), findsOneWidget);
        expect(rows.evaluate().length, lessThan(30));
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(repository.detailRequests.last, ('42', '179', 'version-179'));
        expect(find.text('Archived script'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(first, -500, scrollable: scrollable);
        await tester.pumpAndSettle();
        expect(first.hitTestable(), findsOneWidget);
        expect(last, findsNothing);
        expect(repository.historyPages, [1]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'archive pagination retries and search refreshes the first page',
    (tester) async {
      repository.archivePageSize = 2;
      repository.creations = [
        for (var index = 1; index <= 4; index++)
          IpAccountCreation(id: '$index', title: 'Archive $index'),
      ];
      await pump(tester);
      await openArchives(tester);
      expect(find.byKey(const ValueKey('archive-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('archive-3')), findsNothing);
      repository.failHistory = true;
      await tester.tap(find.byKey(const Key('account-archive-load-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('archive-1')), findsOneWidget);
      final retry = find.byKey(const Key('account-archive-retry'));
      expect(retry, findsOneWidget);
      repository.failHistory = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repository.historyPages, [1, 2, 2]);
      expect(find.byKey(const ValueKey('archive-4')), findsOneWidget);
      expect(find.byKey(const Key('account-archive-load-more')), findsNothing);

      final search = find.byKey(const Key('account-archive-search'));
      await tester.enterText(search, 'Archive 4');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('archive-1')), findsNothing);
      expect(find.byKey(const ValueKey('archive-4')), findsOneWidget);
      expect(repository.historyPages.last, 1);
      expect(repository.historyKeywords.last, 'Archive 4');
      repository.creations = [
        const IpAccountCreation(id: 'refreshed', title: 'Archive 4 refreshed'),
      ];
      final refresh = tester
          .state<RefreshIndicatorState>(
            find.descendant(
              of: find.byType(AccountArchivesPage),
              matching: find.byType(RefreshIndicator),
            ),
          )
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.byKey(const ValueKey('archive-refreshed')), findsOneWidget);
      expect(find.byKey(const ValueKey('archive-4')), findsNothing);
      expect(repository.historyPages.last, 1);
      expect(repository.historyKeywords.last, 'Archive 4');
      expect(tester.widget<TextField>(search).controller!.text, 'Archive 4');
      expect(tester.takeException(), isNull);
    },
  );
}
