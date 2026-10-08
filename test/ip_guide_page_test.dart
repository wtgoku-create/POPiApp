import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/ip_guide/presentation/ip_guide_page.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';

void main() {
  Future<void> pumpGuide(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    bool dark = false,
    Locale locale = const Locale('zh'),
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.only(top: 52, bottom: 34));
    final router = container.read(routerProvider(false));
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('home-start-0')));
    await tester.tap(find.byKey(const Key('home-start-0')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );

  testWidgets(
    'all four steps preserve selections and confirm the exact plan into a session',
    (tester) async {
      await pumpGuide(tester);
      expect(find.byType(IpGuidePage), findsOneWidget);
      expect(find.textContaining('帮你创建IP账号'), findsOneWidget);
      await tap(tester, 'ip-guide-start');
      await tap(tester, 'ip-direction-campus');
      await tap(tester, 'ip-direction-emotion');
      expect(find.text('主方向：校园'), findsOneWidget);
      expect(find.text('辅助：情感'), findsOneWidget);
      await tap(tester, 'ip-guide-next-1');
      await tap(tester, 'ip-feeling-authentic');
      await tap(tester, 'ip-feeling-healing');
      await tap(tester, 'ip-guide-back');
      expect(find.text('主方向：校园'), findsOneWidget);
      await tap(tester, 'ip-guide-next-1');
      expect(find.text('辅助：治愈'), findsOneWidget);
      await tap(tester, 'ip-guide-next-2');
      await tap(tester, 'ip-presentation-animation3d');
      await tap(tester, 'ip-format-comicDrama');
      await tap(tester, 'ip-guide-next-3');
      expect(find.text('校园 × 情感'), findsOneWidget);
      expect(find.text('真实 / 治愈'), findsOneWidget);
      expect(find.text('3D动漫 · 漫剧'), findsOneWidget);
      await tester.enterText(field('ip-nickname'), '校园小故事');
      await tester.pumpAndSettle();
      expect(find.text('校园小故事'), findsNWidgets(2));
      await tap(tester, 'ip-confirm');
      final session = tester.widget<SessionPage>(find.byType(SessionPage));
      expect(session.initialPrompt, contains('账号昵称：校园小故事'));
      expect(session.initialPrompt, contains('内容方向：校园 × 情感'));
      expect(session.initialPrompt, contains('观众感受：真实 / 治愈'));
      expect(session.initialPrompt, contains('呈现形态：3D动漫'));
      expect(session.initialPrompt, contains('内容形式：漫剧'));
      expect(
        tester
            .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
            .controller
            .markdown,
        session.initialPrompt,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tabs retain custom answers and fields enforce character limits',
    (tester) async {
      await pumpGuide(tester);
      await tap(tester, 'ip-guide-tab-1');
      await tap(tester, 'ip-direction-campus');
      await tester.enterText(field('ip-custom-direction'), '独立音乐');
      await tester.pumpAndSettle();
      expect(find.text('主方向：校园'), findsNothing);
      await tap(tester, 'ip-guide-next-1');
      await tester.enterText(field('ip-custom-feeling'), '好奇而轻松');
      await tap(tester, 'ip-guide-next-2');
      await tap(tester, 'ip-presentation-aiReal');
      await tester.enterText(field('ip-custom-format'), '音乐故事');
      await tap(tester, 'ip-guide-next-3');
      expect(find.text('独立音乐'), findsOneWidget);
      expect(find.text('好奇而轻松'), findsOneWidget);
      expect(find.text('AI真人 · 音乐故事'), findsOneWidget);
      await tester.enterText(field('ip-nickname'), 'abcdefghijklmnop');
      await tester.pump();
      expect(
        tester.widget<TextField>(field('ip-nickname')).controller!.text,
        'abcdefghijklmno',
      );
      await tap(tester, 'ip-guide-tab-1');
      expect(
        tester.widget<TextField>(field('ip-custom-direction')).controller!.text,
        '独立音乐',
      );
      await tester.enterText(
        field('ip-custom-direction'),
        '123456789012345678901',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(field('ip-custom-direction'))
            .controller!
            .text
            .length,
        20,
      );
      await tap(tester, 'ip-direction-emotion');
      expect(
        tester.widget<TextField>(field('ip-custom-direction')).controller!.text,
        isEmpty,
      );
      expect(find.text('主方向：情感'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing answers cannot advance or create a session', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    await tap(tester, 'ip-guide-next-1');
    expect(find.text('你想长期分享什么？'), findsOneWidget);
    await tap(tester, 'ip-guide-tab-4');
    await tap(tester, 'ip-confirm');
    expect(find.byType(SessionPage), findsNothing);
    expect(find.text('你想长期分享什么？'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tap(tester, 'ip-guide-back');
    await tap(tester, 'ip-guide-back');
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back steps through the guide and preserves the draft', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    await tap(tester, 'ip-direction-campus');
    await tap(tester, 'ip-guide-next-1');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('主方向：校园'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ip-guide-start')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the primary choice promotes the secondary', (
    tester,
  ) async {
    await pumpGuide(tester);
    await tap(tester, 'ip-guide-start');
    await tap(tester, 'ip-direction-campus');
    await tap(tester, 'ip-direction-emotion');
    await tap(tester, 'ip-direction-growth');
    expect(find.text('辅助：情感'), findsOneWidget);
    await tap(tester, 'ip-direction-campus');
    expect(find.text('主方向：情感'), findsOneWidget);
    expect(find.text('辅助：情感'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'all English dark steps fit $size with large text and reduced motion',
      (tester) async {
        await pumpGuide(
          tester,
          size: size,
          dark: true,
          locale: const Locale('en'),
          textScale: 1.3,
          reducedMotion: true,
        );
        expect(
          tester
              .widget<TabBar>(find.byType(TabBar))
              .controller!
              .animationDuration,
          Duration.zero,
        );
        for (var step = 0; step < 5; step++) {
          await tap(tester, 'ip-guide-tab-$step');
          final key = step == 0
              ? 'ip-guide-start'
              : step == 4
              ? 'ip-confirm'
              : 'ip-guide-next-$step';
          await tester.ensureVisible(find.byKey(Key(key)));
          await tester.pumpAndSettle();
          expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
