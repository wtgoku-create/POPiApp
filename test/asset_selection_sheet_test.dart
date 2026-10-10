import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:popi_ai_app/features/assets/presentation/asset_selection_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/work_library_fixtures.dart';
import 'work_library_test.dart' show TestWorkRepository;

LibraryWork work(int id) => LibraryWork(
  id: '$id',
  previewUrl: 'assets/images/assets_works_gallery_01.png',
  isVideo: false,
  createdAt: DateTime(2026, 9, 1),
);

void main() {
  Future<void> open(
    WidgetTester tester,
    TestWorkRepository repository, {
    void Function(List<LibraryWork>?)? onResult,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [userProvider.overrideWith(LibraryTestUserController.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await AssetSelectionSheet.show(
                    context: context,
                    repository: repository,
                  );
                  onResult?.call(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('initial failure can be retried to the empty state', (
    tester,
  ) async {
    var calls = 0;
    final repository = TestWorkRepository((_, _) async {
      if (calls++ == 0) throw StateError('Offline');
      return const LibraryWorkPage(items: [], hasMore: false);
    });
    await open(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('asset-selection-retry')));
    await tester.pumpAndSettle();
    expect(find.text('暂无作品'), findsOneWidget);
    expect(repository.requests, [(0, 1), (0, 1)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filter changes discard a late response from the previous filter',
    (tester) async {
      final first = Completer<LibraryWorkPage>();
      final repository = TestWorkRepository(
        (type, _) async => type == 0
            ? first.future
            : LibraryWorkPage(items: [work(2)], hasMore: false),
      );
      await open(tester, repository);
      await tester.tap(find.byKey(const Key('role-segment-2')));
      await tester.pumpAndSettle();
      first.complete(LibraryWorkPage(items: [work(1)], hasMore: false));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('asset-library-select-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('asset-library-select-1')),
        findsNothing,
      );
      expect(repository.requests, [(0, 1), (2, 1)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pagination deduplicates works and preserves an offscreen selection',
    (tester) async {
      final repository = TestWorkRepository(
        (_, page) async => LibraryWorkPage(
          items: page == 1
              ? List.generate(40, (i) => work(i + 1))
              : [work(40), work(41)],
          hasMore: page == 1,
        ),
      );
      List<LibraryWork>? result;
      await open(tester, repository, onResult: (value) => result = value);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('asset-library-select-1')));
      await tester.pump();
      final scroll = tester
          .widget<CustomScrollView>(
            find.byKey(const Key('asset-selection-scroll')),
          )
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('asset-library-select-41')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('asset-selection-confirm')));
      await tester.pumpAndSettle();
      expect(repository.requests, [(0, 1), (0, 2)]);
      expect(result!.map((item) => item.id), ['1', '41']);
      expect(tester.takeException(), isNull);
    },
  );
}
