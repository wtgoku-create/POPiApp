import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<T> _pump<T extends DemoRepository>(
  WidgetTester tester,
  Future<T> Function(PreferencesStorage storage) createRepository, {
  Size size = const Size(375, 775),
  Locale locale = const Locale('zh'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final repository = await createRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  );
  repository.restore();
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
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: DemoHomePage(repository: repository),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _openCreationSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('demo-create')));
  await tester.pumpAndSettle();
}

FilledButton _createButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: find.byKey(const Key('demo-create-assistant-confirm')),
    matching: find.byType(FilledButton),
  ),
);

class _RetryingCreateRepository extends DemoRepository {
  _RetryingCreateRepository(super.storage);

  final firstAttempt = Completer<String>();
  final finished = Completer<void>();
  int createCalls = 0;
  String? capturedTitle;
  DemoSessionKind? capturedKind;
  List<String>? capturedMembers;
  DemoAssistantProfile? capturedAssistant;

  @override
  Future<String> createSession(
    String title,
    DemoSessionKind kind, {
    List<String>? members,
    DemoAssistantProfile? assistant,
  }) async {
    createCalls += 1;
    capturedTitle = title;
    capturedKind = kind;
    capturedMembers = members;
    capturedAssistant = assistant;
    if (createCalls == 1) {
      try {
        return await firstAttempt.future;
      } finally {
        finished.complete();
      }
    }
    return super.createSession(
      title,
      kind,
      members: members,
      assistant: assistant,
    );
  }
}

class _CapturingCreateRepository extends DemoRepository {
  _CapturingCreateRepository(super.storage);

  int createCalls = 0;
  String? capturedTitle;
  DemoSessionKind? capturedKind;
  List<String>? capturedMembers;
  DemoAssistantProfile? capturedAssistant;

  @override
  Future<String> createSession(
    String title,
    DemoSessionKind kind, {
    List<String>? members,
    DemoAssistantProfile? assistant,
  }) {
    createCalls += 1;
    capturedTitle = title;
    capturedKind = kind;
    capturedMembers = members;
    capturedAssistant = assistant;
    return super.createSession(
      title,
      kind,
      members: members,
      assistant: assistant,
    );
  }
}

void main() {
  test('all session kinds default to one assistant', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    );
    addTearDown(repository.dispose);

    for (final kind in DemoSessionKind.values) {
      final id = await repository.createSession('单助理', kind);
      expect(repository.session(id).members, ['popi']);
    }
  });

  testWidgets('mobile new conversation opens the new Popi form directly', (
    tester,
  ) async {
    await _pump(tester, (storage) async => DemoRepository(storage));
    await _openCreationSheet(tester);

    expect(find.byType(DemoHomePage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '创建新的 Popi',
      ),
      findsOneWidget,
    );
    expect(find.text('Popi 名称'), findsOneWidget);
    expect(find.byKey(const Key('demo-assistant-name')), findsOneWidget);
    expect(
      find.byKey(const Key('demo-assistant-instructions')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('demo-create-session-name')), findsNothing);
    expect(find.byKey(const Key('demo-create-assistant')), findsNothing);
    expect(find.text('选择助理'), findsNothing);
    expect(tester.getTopLeft(find.byType(BottomSheet)).dy, closeTo(60, 1));
    expect(
      tester
          .getRect(find.byKey(const Key('demo-create-assistant-confirm')))
          .bottom,
      lessThanOrEqualTo(755),
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [1200.0, 950.0]) {
    testWidgets('desktop new button opens the new Popi form at width $width', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await _pump(
          tester,
          (storage) async => DemoRepository(storage),
          size: Size(width, 775),
        );

        expect(
          tester
              .getSize(find.byKey(const Key('demo-desktop-sidebar-frame')))
              .width,
          width >= 1000 ? 280 : 80,
        );
        await tester.tap(find.byKey(const Key('demo-desktop-create')).first);
        await tester.pumpAndSettle();

        expect(find.text('创建新的 Popi'), findsOneWidget);
        expect(find.byKey(const Key('demo-assistant-name')), findsOneWidget);
        expect(find.byKey(const Key('demo-create-session-name')), findsNothing);
        expect(find.text('选择助理'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('English creation form uses the Popi product language', (
    tester,
  ) async {
    await _pump(
      tester,
      (storage) async => DemoRepository(storage),
      size: const Size(390, 844),
      locale: const Locale('en'),
    );
    await _openCreationSheet(tester);

    expect(find.text('Create a new Popi'), findsOneWidget);
    expect(find.text('Popi name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the creation sheet does not create a conversation', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      (storage) async => DemoRepository(storage),
    );
    final before = repository.sessions.length;
    await _openCreationSheet(tester);
    await tester.enterText(
      find.byKey(const Key('demo-assistant-name')),
      '不要保存',
    );
    await tester.enterText(
      find.byKey(const Key('demo-assistant-instructions')),
      '这份职责也应该丢弃。',
    );
    await tester.tap(
      find.byKey(const ValueKey('demo-assistant-avatar-rabbit')),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(repository.sessions, hasLength(before));
    expect(
      repository.assistantProfiles.where((profile) => !profile.isBuiltIn),
      isEmpty,
    );
    expect(find.byType(DemoHomePage), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('empty Popi name disables confirmation', (tester) async {
    await _pump(tester, (storage) async => DemoRepository(storage));
    await _openCreationSheet(tester);

    final name = find.byKey(const Key('demo-assistant-name'));
    expect(_createButton(tester).onPressed, isNull);
    await tester.enterText(name, '一二三四五六七八九十');
    await tester.pump();
    expect(_createButton(tester).onPressed, isNotNull);
    expect(find.text('10/10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all zodiac avatars are available with tiger selected initially',
    (tester) async {
      await _pump(tester, (storage) async => DemoRepository(storage));
      await _openCreationSheet(tester);

      for (final character in BotAvatarCharacter.values) {
        expect(
          find.byKey(ValueKey('demo-assistant-avatar-${character.name}')),
          findsOneWidget,
        );
      }
      final tiger = tester.widget<Semantics>(
        find.byKey(const ValueKey('demo-assistant-avatar-tiger')),
      );
      expect(tiger.properties.selected, isTrue);
      final pink = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('demo-assistant-color-4294959087')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(pink.properties.selected, isTrue);
      expect(BotAvatarCharacter.values, hasLength(12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new Popi profile is submitted atomically and names the session',
    (tester) async {
      final repository = await _pump(
        tester,
        (storage) async => _CapturingCreateRepository(storage),
      );
      await _openCreationSheet(tester);

      await tester.enterText(
        find.byKey(const Key('demo-assistant-name')),
        '一二三四五六七八九十',
      );
      await tester.enterText(
        find.byKey(const Key('demo-assistant-instructions')),
        '帮我整理图文和视频内容。',
      );
      await tester.tap(
        find.byKey(const ValueKey('demo-assistant-avatar-rabbit')),
      );
      final color = find.byKey(
        const ValueKey('demo-assistant-color-4293188862'),
      );
      await tester.ensureVisible(color);
      await tester.pump();
      await tester.tap(color);
      await tester.tap(find.byKey(const Key('demo-create-assistant-confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(DemoChatPage), findsOneWidget);
      expect(repository.createCalls, 1);
      expect(repository.capturedTitle, '一二三四五六七八九十');
      expect(repository.capturedKind, DemoSessionKind.conversation);
      expect(repository.capturedMembers, ['popi']);
      expect(repository.capturedAssistant?.memberId, 'popi');
      expect(repository.capturedAssistant?.name, '一二三四五六七八九十');
      expect(repository.capturedAssistant?.instructions, '帮我整理图文和视频内容。');
      expect(
        repository.capturedAssistant?.avatarAsset,
        'assets/animations/bot_avatars/rabbit.png',
      );
      expect(repository.capturedAssistant?.avatarColor, 0xFFE4DCFE);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'busy and failed creation keep the complete draft and allow retry',
    (tester) async {
      final repository = await _pump(
        tester,
        (storage) async => _RetryingCreateRepository(storage),
      );
      await _openCreationSheet(tester);
      final name = find.byKey(const Key('demo-assistant-name'));
      final instructions = find.byKey(const Key('demo-assistant-instructions'));
      await tester.enterText(name, '保留这份草稿');
      await tester.enterText(instructions, '失败后也不能丢失。');
      await tester.tap(
        find.byKey(const ValueKey('demo-assistant-avatar-rooster')),
      );
      final color = find.byKey(
        const ValueKey('demo-assistant-color-4291818742'),
      );
      tester.testTextInput.hide();
      await tester.ensureVisible(color);
      await tester.pump();
      await tester.tap(color);
      await tester.tap(find.byKey(const Key('demo-create-assistant-confirm')));
      await tester.tap(find.byKey(const Key('demo-create-assistant-confirm')));
      await tester.pump();

      expect(repository.createCalls, 1);
      expect(_createButton(tester).onPressed, isNull);
      expect(tester.widget<TextField>(name).enabled, isFalse);
      expect(tester.widget<TextField>(instructions).enabled, isFalse);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(const ValueKey('demo-assistant-avatar-rooster')),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      expect(tester.widget<InkWell>(color).onTap, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('demo-assistant-random-avatar')),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.drag(find.byType(BottomSheet), const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(repository.createCalls, 1);

      repository.firstAttempt.completeError(Exception('create failed'));
      await tester.runAsync(() => repository.finished.future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(tester.widget<TextField>(name).controller!.text, '保留这份草稿');
      expect(
        tester.widget<TextField>(instructions).controller!.text,
        '失败后也不能丢失。',
      );
      expect(
        repository.capturedAssistant?.avatarAsset,
        BotAvatarCharacter.rooster.stillAsset,
      );
      expect(repository.capturedAssistant?.avatarColor, 0xFFCFF4F6);
      expect(_createButton(tester).onPressed, isNotNull);
      expect(find.text('本地保存失败，请再次操作'), findsOneWidget);

      await tester.tap(find.byKey(const Key('demo-create-assistant-confirm')));
      await tester.pumpAndSettle();
      expect(repository.createCalls, 2);
      expect(repository.sessions.first.title, '保留这份草稿');
      expect(repository.sessions.first.memberInstructions['popi'], '失败后也不能丢失。');
      expect(find.byType(DemoChatPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pinning and renaming retain the pinned list state', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      (storage) async => DemoRepository(storage),
    );

    await tester.longPress(find.text('爱丽丝视频').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();

    expect(repository.session('alice').pinned, isTrue);
    expect(repository.sessions.first.id, 'alice');
    await tester.longPress(find.text('爱丽丝视频').first);
    await tester.pumpAndSettle();
    expect(find.text('取消置顶'), findsOneWidget);
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '置顶创作组');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(repository.sessions.first.id, 'alice');
    expect(repository.sessions.first.title, '置顶创作组');
    expect(repository.sessions.first.pinned, isTrue);
    expect(tester.takeException(), isNull);
  });
}
