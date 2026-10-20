import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/role_guide/domain/role_generation.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_generation_panel.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_HOME_TASK_STATES');
  setUpAll(() async {
    if (!capture) return;
    const path = String.fromEnvironment('HOME_TASK_CAPTURE_FONT');
    if (path.isNotEmpty) {
      final font = FontLoader('HomeTaskCapture')
        ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await font.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final (size, locale, scale, dark) in [
    (const Size(390, 844), const Locale('zh'), 1.0, false),
    (const Size(320, 844), const Locale('zh'), 1.5, true),
    (const Size(1024, 768), const Locale('en'), 1.5, false),
  ]) {
    for (final state in [
      RoleGenerationStatus.pausing,
      RoleGenerationStatus.paused,
      RoleGenerationStatus.canceling,
    ]) {
      testWidgets('${state.name} panel stays consistent at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final theme = dark ? AppTheme.dark : AppTheme.light;
        final l10n = lookupAppLocalizations(locale);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: capture
                  ? theme.copyWith(
                      textTheme: theme.textTheme.apply(
                        fontFamily: 'HomeTaskCapture',
                      ),
                    )
                  : theme,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 440,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: RoleGenerationPanel(
                        progress: RoleGenerationProgress(
                          status: state,
                          stage: 3,
                        ),
                        preview: false,
                        actionLabel: state == RoleGenerationStatus.paused
                            ? l10n.roleResumeProduction
                            : l10n.roleStopProduction,
                        onAction: () {},
                        onStop: () {},
                        onRetry: () {},
                        onContinue: () {},
                        onViewPlan: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(l10n.roleTaskExecuting), findsNothing);
        expect(find.text(l10n.roleWorkGenerating), findsNothing);
        expect(
          find.text(switch (state) {
            RoleGenerationStatus.pausing => l10n.roleStatusPausing,
            RoleGenerationStatus.paused => l10n.roleStatusPaused,
            _ => l10n.roleStatusCanceling,
          }),
          findsOneWidget,
        );
        expect(
          find.byType(CircularProgressIndicator),
          state == RoleGenerationStatus.paused ? findsNothing : findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).gradient != null,
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        if (capture) {
          await tester.runAsync(() async {
            final pixels =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/conversation-ux/home-task-${state.name}-${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
