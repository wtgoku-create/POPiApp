import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_assets_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

class _ControlledImportRepository extends DemoRepository {
  _ControlledImportRepository(super.storage);

  final batches = <List<DemoAssetKind>>[];
  final attempts = <Completer<void>>[];

  @override
  Future<void> importSamples(List<DemoAssetKind> kinds) {
    final batch = List<DemoAssetKind>.unmodifiable(kinds);
    final attempt = Completer<void>();
    batches.add(batch);
    attempts.add(attempt);
    return attempt.future.then((_) => super.importSamples(batch));
  }
}

void main() {
  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(375, 760),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('filters assets and switches to the virtualized list', (
    tester,
  ) async {
    final repository = DemoRepository(storage)..restore();
    addTearDown(repository.dispose);
    await pump(
      tester,
      Scaffold(body: DemoAssetsView(repository: repository)),
      size: const Size(320, 700),
    );

    await tester.enterText(find.byType(TextField), '午后轻音乐');
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(DemoAssetCard),
        matching: find.text('午后轻音乐'),
      ),
      findsOneWidget,
    );
    expect(find.text('奶茶店的午后'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('视频'));
    await tester.pump();
    expect(find.text('周末出游成片'), findsOneWidget);
    expect(find.text('午后的故事'), findsOneWidget);
    expect(find.text('奶茶店的午后'), findsNothing);

    await tester.tap(find.byKey(const Key('demo-assets-layout-toggle')));
    await tester.pump();
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissed import keeps repository unchanged and resets draft', (
    tester,
  ) async {
    final repository = DemoRepository(storage)..restore();
    addTearDown(repository.dispose);
    final initialCount = repository.assets.length;
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDemoImport(context, repository),
            child: const Text('Import'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 4 个文件'), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-import-remove-image')));
    await tester.pump();
    expect(find.text('已选择 3 个文件'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(repository.assets, hasLength(initialCount));

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 4 个文件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy import blocks dismissal and failed batch retries once', (
    tester,
  ) async {
    final repository = _ControlledImportRepository(storage)..restore();
    addTearDown(repository.dispose);
    final initialCount = repository.assets.length;
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDemoImport(context, repository),
            child: const Text('Import'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上传到官方资产库'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('上传素材'), findsOneWidget);
    expect(repository.batches, [DemoAssetKind.values]);
    expect(repository.assets, hasLength(initialCount));

    repository.attempts.single.completeError(StateError('Disk unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('已选择 4 个文件'), findsOneWidget);
    expect(find.byKey(const Key('demo-import-file-image')), findsOneWidget);
    expect(find.text('上传素材'), findsOneWidget);
    expect(repository.assets, hasLength(initialCount));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('上传到官方资产库'));
    await tester.pump();
    expect(repository.batches, [DemoAssetKind.values, DemoAssetKind.values]);
    repository.attempts.last.complete();
    await tester.pumpAndSettle();
    expect(repository.assets, hasLength(initialCount + 4));
    expect(find.text('上传素材'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Harness import never displays bundled files as selected', (
    tester,
  ) async {
    await DemoRepository.prepareHarnessStorage(storage);
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final repository = DemoRepository.harness(storage, NetworkAgentApi(dio))
      ..restore();
    addTearDown(repository.dispose);
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDemoImport(context, repository),
            child: const Text('Import'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 0 个文件'), findsOneWidget);
    expect(find.byKey(const Key('demo-import-file-image')), findsNothing);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
