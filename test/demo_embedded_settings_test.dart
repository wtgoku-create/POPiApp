import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_assets_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<DemoRepository> _repository() async {
  SharedPreferences.setMockInitialValues({});
  return DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
}

Future<void> _pumpEmbedded(
  WidgetTester tester,
  DemoRepository repository, {
  String sessionId = 'alice',
  int initialTab = 0,
  VoidCallback? onClose,
  ValueChanged<int>? onTabChanged,
  Size size = const Size(340, 760),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: DemoSettingsPage(
              repository: repository,
              sessionId: sessionId,
              initialTab: initialTab,
              embedded: true,
              onClose: onClose,
              onTabChanged: onTabChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  testWidgets('embedded inspector uses real identity and closes in place', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    await repository.updateSession(
      'alice',
      (session) => session.copyWith(
        memberInstructions: {
          ...session.memberInstructions,
          'popi': '保持温柔直接，先给结论，再说明创作选择。',
        },
      ),
    );
    var closes = 0;
    await _pumpEmbedded(tester, repository, onClose: () => closes += 1);

    expect(find.byKey(const Key('demo-settings-embedded')), findsOneWidget);
    expect(find.byKey(const Key('demo-inspector-header')), findsOneWidget);
    expect(find.text('保持温柔直接，先给结论，再说明创作选择。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-inspector-close')));
    await tester.pump();
    expect(closes, 1);
    expect(find.byKey(const Key('demo-settings-embedded')), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-settings-rename')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-edit-member-scroll')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('demo-member-name')), '小助手');
    await tester.tap(find.byKey(const Key('demo-member-edit-confirm')));
    await tester.pumpAndSettle();
    expect(repository.session('alice').memberNames['popi'], '小助手');
    expect(find.text('小助手'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded output tab remains scoped to the selected session', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    final tabs = <int>[];
    await _pumpEmbedded(
      tester,
      repository,
      sessionId: 'inspiration',
      initialTab: 2,
      onTabChanged: tabs.add,
    );

    final assets = tester.widget<DemoAssetsView>(find.byType(DemoAssetsView));
    expect(assets.sessionId, 'inspiration');
    expect(assets.compactHeader, isTrue);
    await tester.tap(find.text('信息'));
    await tester.pumpAndSettle();
    expect(tabs, [0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'deleted and initially missing sessions leave no stale inspector',
    (tester) async {
      final repository = await _repository();
      addTearDown(repository.dispose);
      await _pumpEmbedded(tester, repository);

      await repository.deleteSession('alice');
      await tester.pump();
      expect(find.byKey(const Key('demo-settings-embedded')), findsNothing);
      expect(tester.takeException(), isNull);

      await _pumpEmbedded(tester, repository, sessionId: 'missing');
      expect(find.byKey(const Key('demo-settings-embedded')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('embedded inspector supports narrow dark large text', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    await _pumpEmbedded(
      tester,
      repository,
      size: const Size(320, 700),
      textScale: 1.5,
      theme: AppTheme.dark,
    );

    expect(find.byKey(const Key('demo-settings-embedded')), findsOneWidget);
    expect(find.text('职责与个性'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
