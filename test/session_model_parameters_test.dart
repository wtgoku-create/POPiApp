import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/role_guide/domain/role_guide_draft.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_generation_sheet.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';

import 'support/project_fixtures.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    double width = 440,
    bool englishDark = false,
  }) async {
    tester.view.physicalSize = Size(width, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(
            FixtureProjectRepository(),
          ),
        ],
        child: MaterialApp(
          theme: englishDark ? AppTheme.dark : AppTheme.light,
          locale: Locale(englishDark ? 'en' : 'zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(englishDark ? 1.5 : 1)),
            child: child!,
          ),
          home: const SessionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('Keep this prompt');
    await tester.pumpAndSettle();
  }

  Future<void> openParameters(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('popi-model-parameters')));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('role-generation-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('confirmed parameters survive reopening and cancellation', (
    tester,
  ) async {
    await mount(tester);
    await openParameters(tester);
    final initial = tester
        .widget<RoleGenerationSheet>(find.byType(RoleGenerationSheet))
        .initialSettings!;
    expect(initial.model, GenerationModel.sora);
    expect(initial.quantity, 1);
    await select(tester, 'role-model-veo');
    await select(tester, 'role-resolution-1080');
    await select(tester, 'role-ratio-portrait');
    await tester.tap(find.text('图片偏好'));
    await tester.pumpAndSettle();
    await select(tester, 'role-ratio-square');
    await select(tester, 'role-quantity-4');
    await select(tester, 'role-generation-confirm');
    expect(find.byType(RoleGenerationSheet), findsNothing);
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    expect(composer.controller.markdown, 'Keep this prompt');
    expect(composer.modelParametersDescription, contains('Veo 3.1'));
    expect(composer.modelParametersDescription, contains('1080P / 9:16'));

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    await openParameters(tester);
    final saved = tester
        .widget<RoleGenerationSheet>(find.byType(RoleGenerationSheet))
        .initialSettings!;
    expect(saved.model, GenerationModel.veo);
    expect(saved.videoResolution, 1080);
    expect(saved.videoRatio, GenerationRatio.portrait);
    expect(saved.imageResolution, 720);
    expect(saved.imageRatio, GenerationRatio.square);
    expect(saved.quantity, 4);
    await select(tester, 'role-model-kling');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    await openParameters(tester);
    expect(
      tester
          .widget<RoleGenerationSheet>(find.byType(RoleGenerationSheet))
          .initialSettings,
      same(saved),
    );
    expect(tester.takeException(), isNull);
  });

  for (final englishDark in [false, true]) {
    testWidgets(
      'compact composer keeps tools separate, English: $englishDark',
      (tester) async {
        await mount(tester, width: 320, englishDark: englishDark);
        final parameters = tester.getRect(
          find.byKey(const Key('popi-model-parameters')),
        );
        final attachment = tester.getRect(
          find.byTooltip(englishDark ? 'Add attachment' : '添加附件'),
        );
        final voice = tester.getRect(find.byIcon(Icons.mic_none_rounded));
        expect(parameters.left, greaterThanOrEqualTo(attachment.right));
        expect(parameters.right, lessThanOrEqualTo(voice.left));
        expect(tester.takeException(), isNull);
        await openParameters(tester);
        expect(find.byType(RoleGenerationSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
