import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/home_generation_config_sheet.dart';
import 'package:popi_ai_app/features/role_guide/domain/role_guide_draft.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_generation_sheet.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'conversation_controller_test.dart' show StreamingSessionRepository;
import 'home_generation_config_sheet_test.dart' show configFixture, configTap;
import 'support/home_creation_fixtures.dart';
import 'support/project_fixtures.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    double width = 440,
    bool englishDark = false,
    HomeCreationFixture? liveFixture,
    StreamingSessionRepository? sessions,
  }) async {
    tester.view.physicalSize = Size(width, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(FixtureProjectRepository()),
        if (liveFixture != null)
          dioProvider.overrideWithValue(liveFixture.business),
        if (sessions != null)
          sessionRepositoryProvider.overrideWithValue(sessions),
      ],
    );
    addTearDown(container.dispose);
    if (liveFixture != null) {
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'config-user', name: 'Test', email: ''));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    expect(find.byKey(const Key('role-quantity-4')), findsNothing);
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
    expect(saved.quantity, 1);
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

  testWidgets(
    'draft parameters stay local until first send creates a conversation',
    (tester) async {
      final fixture = configFixture();
      final sessions = StreamingSessionRepository();
      addTearDown(sessions.close);
      await mount(tester, liveFixture: fixture, sessions: sessions);
      await openParameters(tester);
      expect(find.byType(HomeGenerationConfigSheet), findsOneWidget);
      expect(sessions.sends, 0);
      expect(find.byType(RoleGenerationSheet), findsNothing);
      await configTap(tester, 'home-config-ratio-9:16');
      await configTap(tester, 'home-config-confirm');
      expect(
        fixture.requests.where((request) => request.method == 'PUT'),
        isEmpty,
      );
      expect(
        (await sessions.list(
          'config-user',
        )).items.where((session) => session.id.startsWith('mock-new-')),
        isEmpty,
      );
      expect(
        tester
            .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
            .controller
            .markdown,
        'Keep this prompt',
      );
      await tester.tap(find.byKey(const Key('popi-message-input')));
      await tester.pumpAndSettle();
      await openParameters(tester);
      expect(
        tester
            .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
            .modelParametersDescription,
        contains('9:16'),
      );
      await configTap(tester, 'home-config-confirm');
      expect(
        fixture.requests.where((request) => request.method == 'PUT'),
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('popi-send-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(sessions.sends, 1);
      final writes = fixture.requests.where(
        (request) => request.method == 'PUT',
      );
      expect(writes, hasLength(2));
      expect(
        writes.every((request) => request.data['sessionId'] == 'mock-new-1'),
        isTrue,
      );
      expect(
        (await sessions.list(
          'config-user',
        )).items.where((session) => session.id.startsWith('mock-new-')),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'failed draft preference save retains the session and prompt for retry',
    (tester) async {
      final fixture = configFixture();
      final sessions = StreamingSessionRepository();
      addTearDown(sessions.close);
      await mount(tester, liveFixture: fixture, sessions: sessions);
      await openParameters(tester);
      await configTap(tester, 'home-config-confirm');
      fixture.failPreferenceSaveOnce = true;
      final send = find.byKey(const Key('popi-send-button'));
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(sessions.sends, 0);
      expect(
        tester
            .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
            .controller
            .markdown,
        'Keep this prompt',
      );
      expect(
        (await sessions.list(
          'config-user',
        )).items.where((session) => session.id.startsWith('mock-new-')),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(sessions.sends, 1);
      final writes = fixture.requests.where(
        (request) => request.method == 'PUT',
      );
      expect(writes, hasLength(3));
      expect(
        writes.every((request) => request.data['sessionId'] == 'mock-new-1'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

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
        final send = tester.getRect(find.byKey(const Key('popi-send-button')));
        expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
        expect(parameters.left, greaterThanOrEqualTo(attachment.right));
        expect(parameters.right, lessThanOrEqualTo(send.left));
        expect(tester.takeException(), isNull);
        await openParameters(tester);
        expect(find.byType(RoleGenerationSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
