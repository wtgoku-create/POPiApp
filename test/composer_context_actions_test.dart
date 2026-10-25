import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('host context chips and add action do not affect default hosts', (
    tester,
  ) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);

    Future<void> pump({required bool extended}) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PopiMessageComposer(
                controller: controller,
                selectedImages: const [],
                onAttachment: () {},
                onRemoveImage: (_) {},
                onHeightChanged: (_) {},
                onSubmitted: (_) {},
                contextChips: extended
                    ? const [
                        SizedBox(
                          key: Key('film-style-chip'),
                          height: 44,
                          child: Text('油画厚涂'),
                        ),
                      ]
                    : const [],
                attachmentAction: extended
                    ? const SizedBox.square(
                        key: Key('film-add-menu'),
                        dimension: 40,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );

    await pump(extended: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('popi-composer-context-chips')), findsNothing);
    expect(find.byKey(const Key('film-add-menu')), findsNothing);
    expect(find.byTooltip('添加附件'), findsOneWidget);

    await pump(extended: true);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('popi-composer-context-chips')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('film-style-chip')), findsOneWidget);
    expect(find.byKey(const Key('film-add-menu')), findsOneWidget);
    expect(find.byTooltip('添加附件'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-cancellable running work shows status without Stop', (
    tester,
  ) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);

    Future<void> pump({required bool canStop}) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PopiMessageComposer(
                controller: controller,
                selectedImages: const [],
                onAttachment: () {},
                onRemoveImage: (_) {},
                onHeightChanged: (_) {},
                onSubmitted: (_) {},
                running: true,
                canStopRunning: canStop,
                onStop: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await pump(canStop: false);
    await tester.pump();
    expect(find.byKey(const Key('popi-running-indicator')), findsOneWidget);
    expect(find.byTooltip('停止回复'), findsNothing);
    expect(find.byKey(const Key('popi-send-button')), findsNothing);

    await pump(canStop: true);
    await tester.pump();
    expect(find.byKey(const Key('popi-running-indicator')), findsNothing);
    expect(find.byTooltip('停止回复'), findsOneWidget);
    expect(find.byKey(const Key('popi-send-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
