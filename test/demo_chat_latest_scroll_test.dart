import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_bot_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  late Dio dio;
  late _LatestScrollApi api;
  late DemoRepository repository;

  setUp(() async {
    AppBotAvatar.debugAnimationsEnabled = false;
    dio = Dio();
    api = _LatestScrollApi(dio)..messages = _history();
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    repository = _LatestRepository(storage, api)..restore();
    await repository.refreshSessions();
  });

  tearDown(() {
    AppBotAvatar.debugAnimationsEnabled = true;
    repository.dispose();
    dio.close(force: true);
    toastification.dismissAll(delayForAnimation: false);
  });

  testWidgets(
    'sending from old history immediately reveals the latest status',
    (tester) async {
      await _pumpChat(tester, repository);
      final position = _position(tester);
      expect(position.pixels, lessThan(position.maxScrollExtent - 100));

      api.sendGate = Completer<Map<String, dynamic>>();
      await _composer(tester).controller.setText('继续生成最新内容');
      await tester.pump();
      _composer(tester).onSubmitted(_composer(tester).controller.markdown);
      await _pumpFrames(tester);

      expect(api.sendCalls, 1);
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
      expect(find.text('正在思考你的内容').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('a growing last reply remains visible while following latest', (
    tester,
  ) async {
    await _pumpChat(tester, repository);
    final position = _position(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    const finalLine = '这是持续输出后的最后一行，需要保持在输入框上方。';
    final paragraphs = List.filled(16, '回复继续增长，正文会占用更多高度。').join('\n\n');
    final controller = tester.widget<Chat>(find.byType(Chat)).chatController;
    final old =
        controller.messages
                .where((message) => message.id == 'assistant-23')
                .single
            as chat.TextMessage;
    final text = '$paragraphs\n\n$finalLine';
    await controller.updateMessage(
      old,
      old.copyWith(
        text: text,
        metadata: {
          'demo': DemoMessage(id: old.id, text: text, memberId: 'popi'),
        },
      ),
    );
    await _pumpFrames(tester);

    expect(find.textContaining(finalLine).hitTestable(), findsOneWidget);
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
  });

  testWidgets(
    'reading older history pauses follow while the latest reply grows',
    (tester) async {
      await _pumpChat(tester, repository);
      final position = _position(tester)
        ..jumpTo(_position(tester).maxScrollExtent);
      await tester.pump();
      final scrollable = find
          .descendant(
            of: find.byType(ChatAnimatedList),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scrollable, const Offset(0, 420));
      await _pumpFrames(tester);
      final readingOffset = position.pixels;
      expect(readingOffset, lessThan(position.maxScrollExtent - 100));

      final text = List.filled(12, '生成结果继续输出，但不应打断历史阅读。').join('\n\n');
      await _replaceMessageText(tester, id: 'assistant-23', text: text);
      await _pumpFrames(tester);

      expect(position.pixels, closeTo(readingOffset, 1));
      expect(find.textContaining('生成结果继续输出').hitTestable(), findsNothing);
    },
  );

  testWidgets('a completed send does not yank a history reader to latest', (
    tester,
  ) async {
    await _pumpChat(tester, repository);
    final position = _position(tester)
      ..jumpTo(_position(tester).maxScrollExtent);
    await tester.pump();
    api
      ..sendGate = Completer<Map<String, dynamic>>()
      ..snapshotGate = Completer<Map<String, dynamic>>();
    await _composer(tester).controller.setText('完成后仍然留在历史位置');
    _composer(tester).onSubmitted(_composer(tester).controller.markdown);
    await _pumpFrames(tester);
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));

    api.sendGate!.complete({'runId': 'run-latest', 'state': 'queued'});
    await _pumpUntil(
      tester,
      () => _composer(tester).controller.markdown.isEmpty,
    );
    await _pumpUntil(tester, () => api.snapshotCalls >= 2);
    final scrollable = find
        .descendant(
          of: find.byType(ChatAnimatedList),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, 420));
    await _pumpFrames(tester);
    final readingOffset = position.pixels;
    expect(readingOffset, lessThan(position.maxScrollExtent - 100));

    api
      ..messages = [
        ..._history(),
        _userMessage('completed-user', '完成后仍然留在历史位置'),
        _assistantMessage(
          'completed-reply',
          List.filled(10, '生成已经完成，但用户仍在查看前面的内容。').join('\n\n'),
        ),
      ]
      ..runState = 'completed';
    api.lastSeq++;
    api.snapshotGate!.complete(api.snapshot());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _pumpFrames(tester);
    await _pumpFrames(tester);
    expect(
      repository
          .session('scroll-session')
          .messages
          .map((message) => message.id),
      contains('completed-reply'),
    );
    await _pumpFrames(tester);

    expect(position.pixels, closeTo(readingOffset, 1));
    expect(find.textContaining('生成已经完成').hitTestable(), findsNothing);
  });

  testWidgets('a new send resumes follow after reading older history', (
    tester,
  ) async {
    await _pumpChat(tester, repository);
    final position = _position(tester)
      ..jumpTo(_position(tester).maxScrollExtent);
    await tester.pump();
    final scrollable = find
        .descendant(
          of: find.byType(ChatAnimatedList),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, 420));
    await _pumpFrames(tester);
    expect(position.pixels, lessThan(position.maxScrollExtent - 100));

    api.sendGate = Completer<Map<String, dynamic>>();
    await _composer(tester).controller.setText('从这里继续新对话');
    _composer(tester).onSubmitted(_composer(tester).controller.markdown);
    await _pumpFrames(tester);

    expect(find.text('正在思考你的内容').hitTestable(), findsOneWidget);
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
  });

  testWidgets('an active desktop chat initially opens at the latest message', (
    tester,
  ) async {
    await _pumpChat(tester, repository, desktopLayout: true);
    final position = _position(tester);

    expect(position.maxScrollExtent, greaterThan(100));
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    expect(find.textContaining('第 23 条历史回复').hitTestable(), findsOneWidget);
  });
}

Future<void> _pumpChat(
  WidgetTester tester,
  DemoRepository repository, {
  bool desktopLayout = false,
}) async {
  tester.view.physicalSize = desktopLayout
      ? const Size(1200, 800)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
          home: DemoChatPage(
            repository: repository,
            sessionId: 'scroll-session',
            desktopLayout: desktopLayout,
          ),
        ),
      ),
    ),
  );
  for (
    var attempt = 0;
    attempt < 40 && repository.isSessionLoading('scroll-session');
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(repository.isSessionLoading('scroll-session'), isFalse);
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 40 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
}

Future<void> _replaceMessageText(
  WidgetTester tester, {
  required String id,
  required String text,
}) async {
  final controller = tester.widget<Chat>(find.byType(Chat)).chatController;
  final old =
      controller.messages.where((message) => message.id == id).single
          as chat.TextMessage;
  await controller.updateMessage(
    old,
    old.copyWith(
      text: text,
      metadata: {'demo': DemoMessage(id: old.id, text: text, memberId: 'popi')},
    ),
  );
}

PopiMessageComposer _composer(WidgetTester tester) =>
    tester.widget<PopiMessageComposer>(find.byType(PopiMessageComposer));

ScrollPosition _position(WidgetTester tester) => tester
    .widget<ChatAnimatedList>(find.byType(ChatAnimatedList))
    .scrollController!
    .position;

List<Map<String, Object?>> _history() => [
  for (var i = 0; i < 24; i++)
    i.isEven
        ? _userMessage('user-$i', '第 $i 条历史问题：请继续说明这个方案。')
        : _assistantMessage(
            'assistant-$i',
            '第 $i 条历史回复。这里有两行内容，用来构成可以向上翻阅的长会话。\n'
                '第二行继续解释方案细节。',
          ),
];

Map<String, Object?> _userMessage(String id, String text) => {
  'id': id,
  'role': 'user',
  'text': text,
  'status': 'completed',
  'createdAt': '2026-10-25T00:00:00.000Z',
};

Map<String, Object?> _assistantMessage(String id, String text) => {
  'id': id,
  'role': 'assistant',
  'memberId': 'popi',
  'text': text,
  'status': 'completed',
  'createdAt': '2026-10-25T00:00:00.000Z',
};

final class _LatestScrollApi extends NetworkAgentApi {
  _LatestScrollApi(super.dio);

  List<Map<String, Object?>> messages = [];
  Completer<Map<String, dynamic>>? sendGate;
  Completer<Map<String, dynamic>>? snapshotGate;
  String? runState;
  int lastSeq = 1;
  int sendCalls = 0;
  int snapshotCalls = 0;

  Map<String, dynamic> snapshot() => {
    'session': _record,
    'lastSeq': lastSeq,
    'messages': messages,
    'mediaJobs': <Object?>[],
    'runs': [
      if (runState != null) {'id': 'run-latest', 'state': runState},
    ],
  };

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [_record],
    'pageInfo': {'page': 1, 'pageSize': 20, 'pageCount': 1, 'total': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    snapshotCalls++;
    return snapshotGate != null ? snapshotGate!.future : snapshot();
  }

  @override
  Future<Map<String, dynamic>> updateSession(
    String id, {
    String? clientRequestId,
    String? title,
    bool? archived,
    bool? pinned,
    Map<String, Object?>? configuration,
    int? expectedConfigRevision,
    CancelToken? cancelToken,
  }) async => Map<String, dynamic>.from(_record);

  @override
  Future<Map<String, dynamic>> sendSessionMessage(
    String id, {
    required String clientRequestId,
    required String text,
    String? taskId,
    List<String>? mediaIds,
    List<String>? contextRoleIds,
    Map<String, Object?>? skillInvocation,
    CancelToken? cancelToken,
  }) {
    sendCalls++;
    return sendGate!.future;
  }
}

final class _LatestRepository extends DemoRepository {
  _LatestRepository(super.storage, super.api)
    : super.harness(pollInterval: Duration.zero, maxPollAttempts: 0);

  @override
  Future<void> resumeHarnessSession(String id) async {}
}

final _record = <String, Object?>{
  'id': 'scroll-session',
  'title': 'POPi',
  'kind': 'conversation',
  'revision': 1,
  'createdAt': '2026-10-25T00:00:00.000Z',
  'updatedAt': '2026-10-25T00:00:00.000Z',
  'archived': false,
  'bindingStatus': 'ready',
  'configurationStatus': 'configured',
  'configRevision': 1,
  'configuration': {
    'members': ['popi'],
    'roles': <String>[],
    'capabilities': <String>[],
    'memberNames': {'popi': 'POPi'},
    'memberInstructions': <String, String>{},
    'memberAvatars': <String, String>{},
    'memberColors': <String, int>{},
    'memberCapabilities': <String, Object?>{},
    'workMode': 'onDemand',
    'activeMemberId': 'popi',
  },
};
