import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/assets_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_skeleton.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pump();
  }

  for (final dark in [false, true]) {
    testWidgets('empty asset loading shows a responsive grid in dark: $dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPage(
        tester,
        const AssetsPage(isLoadingWorks: true),
        dark: dark,
      );
      expect(find.byKey(const Key('assets-works-skeleton')), findsOneWidget);
      expect(find.byKey(const Key('assets-works-empty-state')), findsNothing);
      expect(find.byType(AppSkeletonBox), findsNWidgets(10));
      final bounds = tester.getRect(find.byType(AppSkeletonGrid));
      final fade = find.descendant(
        of: find.byType(AppSkeleton),
        matching: find.byType(FadeTransition),
      );
      final before = tester.widget<FadeTransition>(fade).opacity.value;
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<FadeTransition>(fade).opacity.value, isNot(before));
      expect(tester.getRect(find.byType(AppSkeletonGrid)), bounds);
      expect(tester.takeException(), isNull);
      await pumpPage(tester, const AssetsPage(), dark: dark);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assets-works-skeleton')), findsNothing);
      expect(find.byKey(const Key('assets-works-empty-state')), findsOneWidget);
    });
  }

  testWidgets('populated assets stay visible while refreshing', (tester) async {
    await pumpPage(tester, const AssetsPage.sample(isLoadingWorks: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assets-works-skeleton')), findsNothing);
    expect(find.byKey(const Key('assets-works-grid')), findsOneWidget);
    expect(find.byKey(const Key('assets-work-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared list skeleton respects reduced motion', (tester) async {
    await pumpPage(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: AppSkeletonList(label: 'Loading roles'),
        ),
      ),
      reduceMotion: true,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byType(AppSkeleton),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
