import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/session_artifacts_sheet.dart';
import 'package:popi_ai_app/features/v2_assets/presentation/v2_assets_page.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_repository.dart';
import 'package:popi_ai_app/features/v2_shared/domain/v2_models.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<V2Repository> _pump(
  WidgetTester tester, {
  bool list = false,
  ValueChanged<V2Asset>? onSelect,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final repository = V2Repository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  );
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: V2AssetsView(repository: repository, onSelect: onSelect),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (list) {
    await tester.tap(find.byTooltip('产物'));
    await tester.pumpAndSettle();
  }
  return repository;
}

Future<void> _openMenu(WidgetTester tester, String title) async {
  await tester.longPress(find.text(title).first);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('app-context-menu-preview')), findsOneWidget);
  expect(find.text('资产详情'), findsNothing);
  expect(find.text('重命名'), findsOneWidget);
  expect(find.text('删除'), findsOneWidget);
  expect(find.byType(SessionArtifactDetailPage), findsNothing);
}

void main() {
  for (final list in [false, true]) {
    final layout = list ? 'list' : 'grid';
    testWidgets('$layout long press renames the asset and persists it', (
      tester,
    ) async {
      final repository = await _pump(tester, list: list);
      final asset = repository.assets.first;
      await _openMenu(tester, asset.title);
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-context-menu-preview')), findsNothing);
      expect(find.text('重命名资产'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Updated asset');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(
        repository.assets.firstWhere((a) => a.id == asset.id).title,
        'Updated asset',
      );
      final restored = V2Repository(
        PreferencesStorage(await SharedPreferences.getInstance()),
      )..restore();
      addTearDown(restored.dispose);
      expect(
        restored.assets.firstWhere((a) => a.id == asset.id).title,
        'Updated asset',
      );
      expect(find.text('Updated asset'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$layout selection mode keeps tap selection without a menu', (
      tester,
    ) async {
      V2Asset? selected;
      final repository = await _pump(
        tester,
        list: list,
        onSelect: (asset) => selected = asset,
      );
      final asset = repository.assets.first;
      await tester.longPress(find.text(asset.title));
      await tester.pumpAndSettle();
      expect(find.byType(AppContextMenu), findsNothing);
      expect(find.byKey(const Key('app-context-menu-panel')), findsNothing);
      selected = null;
      await tester.tap(find.text(asset.title));
      await tester.pumpAndSettle();
      expect(selected?.id, asset.id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long press deletion requires confirmation and supports cancel', (
    tester,
  ) async {
    final repository = await _pump(tester);
    final asset = repository.assets.first;
    await _openMenu(tester, asset.title);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-context-menu-preview')), findsNothing);
    expect(repository.assets.any((a) => a.id == asset.id), isTrue);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.assets.any((a) => a.id == asset.id), isTrue);
    await _openMenu(tester, asset.title);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(repository.assets.any((a) => a.id == asset.id), isFalse);
    expect(find.text(asset.title), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an asset still opens its details', (tester) async {
    final repository = await _pump(tester);
    await tester.tap(find.text(repository.assets.first.title));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-context-menu-preview')), findsNothing);
    expect(find.byType(SessionArtifactDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
