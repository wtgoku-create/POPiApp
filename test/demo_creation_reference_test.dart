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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<T> _pump<T extends DemoRepository>(
  WidgetTester tester,
  Future<T> Function(PreferencesStorage storage) createRepository, {
  Size size = const Size(375, 775),
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
          locale: const Locale('zh'),
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
    of: find.byKey(const Key('demo-create-session-action')),
    matching: find.byType(FilledButton),
  ),
);

Future<void> _scrollToMember(WidgetTester tester, String memberId) async {
  tester.testTextInput.hide();
  await tester.pump();
  final member = find.byKey(ValueKey('demo-create-member-$memberId'));
  final scrollable = find.descendant(
    of: find.byKey(const Key('demo-create-session-scroll')),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  await tester.scrollUntilVisible(member, 180, scrollable: scrollable.first);
  await tester.pump();
  final viewportBottom = tester.getBottomRight(scrollable.first).dy;
  final overlap = tester.getBottomRight(member).dy - viewportBottom;
  if (overlap > -8) {
    await tester.drag(scrollable.first, Offset(0, -(overlap + 48)));
    await tester.pump();
  }
}

class _ControlledCreateRepository extends DemoRepository {
  _ControlledCreateRepository(super.storage);

  final completer = Completer<String>();
  final finished = Completer<void>();
  int createCalls = 0;
  DemoAssistantProfile? capturedAssistant;

  @override
  Future<String> createSession(
    String title,
    DemoSessionKind kind, {
    List<String>? members,
    DemoAssistantProfile? assistant,
  }) async {
    createCalls += 1;
    capturedAssistant = assistant;
    try {
      return await completer.future;
    } finally {
      finished.complete();
    }
  }
}

class _CapturingCreateRepository extends DemoRepository {
  _CapturingCreateRepository(super.storage);

  int createCalls = 0;
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

  testWidgets('new conversation opens the single assistant sheet directly', (
    tester,
  ) async {
    await _pump(tester, (storage) async => DemoRepository(storage));
    await _openCreationSheet(tester);

    expect(find.byType(DemoHomePage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '新建会话',
      ),
      findsOneWidget,
    );
    expect(find.text('选择助理'), findsOneWidget);
    expect(find.text('创建新助理'), findsOneWidget);
    expect(find.text('当前仅支持选择一名助理'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(BottomSheet)).dy, closeTo(60, 1));
    expect(
      tester
          .getRect(find.byKey(const Key('demo-create-session-action')))
          .bottom,
      lessThanOrEqualTo(755),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop new button opens the same single assistant sheet', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await _pump(
        tester,
        (storage) async => DemoRepository(storage),
        size: const Size(1200, 775),
      );

      await tester.tap(find.byKey(const Key('demo-desktop-create')).first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('demo-create-session-name')), findsOneWidget);
      expect(find.text('选择助理'), findsOneWidget);
      expect(find.text('创建新助理'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(repository.sessions, hasLength(before));
    expect(find.byType(DemoHomePage), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('assistant selection replaces the previous choice', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      (storage) async => DemoRepository(storage),
    );
    await _openCreationSheet(tester);

    final name = find.byKey(const Key('demo-create-session-name'));
    await tester.enterText(name, '');
    await tester.pump();
    expect(_createButton(tester).onPressed, isNull);

    await tester.enterText(name, '校园生活制作组');
    await _scrollToMember(tester, 'writer');
    await tester.tap(find.byKey(const ValueKey('demo-create-member-writer')));
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('demo-create-member-writer')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
    await _scrollToMember(tester, 'sound');
    await tester.tap(find.byKey(const ValueKey('demo-create-member-sound')));
    await tester.pump();
    expect(_createButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('demo-create-session-action')));
    await tester.pumpAndSettle();

    expect(find.byType(DemoChatPage), findsOneWidget);
    expect(repository.sessions.first.title, '校园生活制作组');
    expect(repository.sessions.first.members, ['sound']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new assistant draft is submitted atomically with one member', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      (storage) async => _CapturingCreateRepository(storage),
    );
    await _openCreationSheet(tester);

    await tester.tap(find.byKey(const Key('demo-create-assistant')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-assistant-name')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('demo-assistant-avatar-rabbit')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('demo-assistant-name')),
      '灵感搭档',
    );
    await tester.enterText(
      find.byKey(const Key('demo-assistant-instructions')),
      '帮我整理图文和视频内容。',
    );
    await tester.tap(
      find.byKey(const ValueKey('demo-assistant-avatar-rabbit')),
    );
    final color = find.byKey(const ValueKey('demo-assistant-color-4293188862'));
    await tester.ensureVisible(color);
    await tester.pump();
    await tester.tap(color);
    await tester.tap(find.byKey(const Key('demo-create-assistant-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('灵感搭档'), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-create-session-action')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.capturedKind, DemoSessionKind.conversation);
    expect(repository.capturedMembers, ['popi']);
    expect(repository.capturedAssistant?.memberId, 'popi');
    expect(repository.capturedAssistant?.name, '灵感搭档');
    expect(repository.capturedAssistant?.instructions, '帮我整理图文和视频内容。');
    expect(
      repository.capturedAssistant?.avatarAsset,
      'assets/animations/bot_avatars/rabbit.png',
    );
    expect(repository.capturedAssistant?.avatarColor, 0xFFE4DCFE);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelling new assistant keeps the built-in assistant selected',
    (tester) async {
      await _pump(tester, (storage) async => DemoRepository(storage));
      await _openCreationSheet(tester);

      await tester.tap(find.byKey(const Key('demo-create-assistant')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('demo-assistant-name')),
        '不要保存',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('不要保存'), findsNothing);
      expect(find.text('POPi助手'), findsOneWidget);
      expect(
        find.byKey(const Key('demo-create-session-action')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'busy and failed creation keep the draft without duplicate calls',
    (tester) async {
      final repository = await _pump(
        tester,
        (storage) async => _ControlledCreateRepository(storage),
      );
      await _openCreationSheet(tester);
      final name = find.byKey(const Key('demo-create-session-name'));
      await tester.enterText(name, '保留这份草稿');
      await _scrollToMember(tester, 'writer');
      await tester.tap(find.byKey(const ValueKey('demo-create-member-writer')));
      await tester.tap(find.byKey(const Key('demo-create-session-action')));
      await tester.pump();

      expect(repository.createCalls, 1);
      expect(_createButton(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.completer.completeError(Exception('create failed'));
      await tester.runAsync(() => repository.finished.future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(tester.widget<TextField>(name).controller!.text, '保留这份草稿');
      expect(repository.capturedAssistant?.memberId, 'writer');
      expect(_createButton(tester).onPressed, isNotNull);
      expect(find.text('本地保存失败，请再次操作'), findsOneWidget);
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
