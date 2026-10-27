import 'dart:convert';

import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

DemoSession _session({
  List<String> members = const ['popi'],
  List<String> roles = const [],
  Map<String, DemoRoleProfile> roleProfiles = const {},
  List<DemoMessage> messages = const [],
}) => DemoSession(
  id: 'new-session',
  title: '新会话',
  kind: DemoSessionKind.project,
  members: members,
  roles: roles,
  roleProfiles: roleProfiles,
  messages: messages,
);

Future<DemoRepository> _repository(
  DemoSession session, {
  List<DemoAsset> assets = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': [session.toJson()],
      'assets': assets.map((asset) => asset.toJson()).toList(),
    }),
  });
  return DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
}

Future<DemoRepository> _pumpChat(
  WidgetTester tester,
  DemoSession session, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('zh'),
  double textScale = 1,
  List<DemoAsset> assets = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = await _repository(session, assets: assets);
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: DemoChatPage(repository: repository, sessionId: session.id),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  testWidgets('new empty session shows both optional content role entrances', (
    tester,
  ) async {
    await _pumpChat(tester, _session());

    expect(
      find.byKey(const Key('demo-new-session-role-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('demo-link-content-role')), findsOneWidget);
    expect(find.byKey(const Key('demo-upload-diy-role')), findsOneWidget);
    expect(find.byKey(const Key('popi-message-input')), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-link-content-role')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-roles-confirm')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('demo-roles-confirm'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('demo-upload-diy-role')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-diy-role-save')), findsOneWidget);
  });

  testWidgets(
    'linked role replaces onboarding with ready state and focus CTA',
    (tester) async {
      final repository = await _pumpChat(tester, _session());
      await repository.updateSession(
        'new-session',
        (session) => session.copyWith(
          roles: const ['role-1'],
          roleProfiles: const {
            'role-1': DemoRoleProfile(
              name: '阿璃',
              instructions: '固定角色外观',
              revision: 'ready-1',
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('demo-new-session-role-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('demo-new-session-role-ready')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('demo-new-session-role-ready')),
          matching: find.text('阿璃'),
        ),
        findsOneWidget,
      );
      expect(repository.session('new-session').messages, isEmpty);

      await tester.tap(find.byKey(const Key('demo-start-creating')));
      await tester.pump();
      final input = tester.widget<ExtendedTextField>(
        find.byKey(const Key('popi-message-input')),
      );
      expect(input.focusNode!.hasFocus, isTrue);
      expect(repository.session('new-session').messages, isEmpty);
    },
  );

  testWidgets('cancelling DIY upload preserves the composer draft', (
    tester,
  ) async {
    await _pumpChat(tester, _session());
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    await composer.controller.setText('保留我的创作想法');

    await tester.tap(find.byKey(const Key('demo-upload-diy-role')));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const Key('demo-diy-role-save'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(composer.controller.markdown, '保留我的创作想法');
    expect(
      find.byKey(const Key('demo-new-session-role-empty')),
      findsOneWidget,
    );
  });

  testWidgets('name-only custom role stays pending and offers profile entry', (
    tester,
  ) async {
    await _pumpChat(
      tester,
      _session(
        roles: const ['custom:legacy'],
        roleProfiles: const {'custom:legacy': DemoRoleProfile(name: '旧角色')},
      ),
    );

    expect(
      find.byKey(const Key('demo-new-session-role-pending')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('demo-start-creating')), findsNothing);
    expect(find.byKey(const Key('demo-complete-role-context')), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-complete-role-context')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('demo-role-profile-custom:legacy')),
      findsOneWidget,
    );
  });

  testWidgets('composer cast avatar prefers the linked role reference image', (
    tester,
  ) async {
    const reference = DemoAsset(
      id: 'role-reference',
      title: '角色参考图',
      kind: DemoAssetKind.image,
      cover: 'assets/images/demo_role_2.png',
    );
    await _pumpChat(
      tester,
      _session(
        roles: const ['custom:reference'],
        roleProfiles: const {
          'custom:reference': DemoRoleProfile(
            name: '参考角色',
            referenceAssetIds: ['role-reference'],
            revision: 'ready-reference',
          ),
        },
      ),
      assets: const [reference],
    );

    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    expect(composer.castRoles!.single.avatar, 'assets/images/demo_role_2.png');
  });

  testWidgets('existing conversation never inserts the new-session guide', (
    tester,
  ) async {
    await _pumpChat(
      tester,
      _session(
        messages: const [DemoMessage(id: 'existing', text: '已有消息', user: true)],
      ),
    );

    expect(find.byKey(const Key('demo-new-session-role-guide')), findsNothing);
    expect(find.text('已有消息'), findsOneWidget);
  });

  testWidgets(
    'legacy empty multi-assistant chat does not show role onboarding',
    (tester) async {
      await _pumpChat(tester, _session(members: const ['popi', 'writer']));

      expect(
        find.byKey(const Key('demo-new-session-role-guide')),
        findsNothing,
      );
      expect(find.byKey(const Key('popi-message-input')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow English layout supports large text without overflow', (
    tester,
  ) async {
    await _pumpChat(
      tester,
      _session(),
      size: const Size(320, 700),
      locale: const Locale('en'),
      textScale: 1.35,
    );

    expect(
      find.byKey(const Key('demo-new-session-role-guide')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('demo-link-content-role')), findsOneWidget);
    expect(find.byKey(const Key('demo-upload-diy-role')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
