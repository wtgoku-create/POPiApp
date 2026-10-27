import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_assets_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_image_stack.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_bot_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  late Dio dio;
  late _InlineChatApi api;
  late _InlineChatRepository repository;

  setUp(() async {
    AppBotAvatar.debugAnimationsEnabled = false;
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
    api = _InlineChatApi(dio);
    repository = _InlineChatRepository(storage, api)..restore();
    await repository.refreshSessions();
  });

  tearDown(() {
    AppBotAvatar.debugAnimationsEnabled = true;
    repository.dispose();
    dio.close(force: true);
    toastification.dismissAll(delayForAnimation: false);
  });

  testWidgets(
    'chat deduplicates verified text bodies while preserving image and PDF rendering',
    (tester) async {
      await _pumpChat(tester, repository);

      expect(
        find.byKey(const Key('inline-text-text-message-script-txt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('inline-text-text-message-script-md')),
        findsNothing,
      );
      expect(find.byType(DemoImageStack), findsOneWidget);
      final cards = tester.widgetList<DemoAssetCard>(
        find.byType(DemoAssetCard),
      );
      expect(cards.map((card) => card.asset.id), ['document-pdf']);
      expect(find.text('聊天内联正文'), findsOneWidget);
    },
  );

  testWidgets('chat keeps expansion state when its message subtree rebuilds', (
    tester,
  ) async {
    api.messages = [
      _message('old-text', text: '较早的文本产物', assetIds: const ['long-text']),
    ];
    repository.dispose();
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    repository = _InlineChatRepository(storage, api)..restore();
    await repository.refreshSessions();
    await _pumpChat(tester, repository);

    final block = find.byKey(const Key('inline-text-old-text-long-text'));
    expect(block, findsOneWidget);
    await tester.tap(
      find.byKey(const Key('demo-inline-text-expand-long-text')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('demo-inline-text-chunk-long-text-0')),
      findsOneWidget,
    );

    await _pumpChat(tester, repository);

    expect(block, findsOneWidget);
    expect(
      find.byKey(const Key('demo-inline-text-chunk-long-text-0')),
      findsOneWidget,
    );
  });

  testWidgets(
    'expanding and collapsing source does not jump the chat to latest',
    (tester) async {
      api.messages = [
        for (var index = 0; index < 14; index++)
          _message(
            'history-$index',
            text: '历史消息 $index：${List.filled(4, '保持足够高度用于滚动验证。').join()}',
          ),
        _message('bottom-text', text: '最新文本产物', assetIds: const ['long-text']),
      ];
      repository.dispose();
      SharedPreferences.setMockInitialValues({});
      final storage = PreferencesStorage(await SharedPreferences.getInstance());
      await DemoRepository.prepareHarnessStorage(storage);
      repository = _InlineChatRepository(storage, api)..restore();
      await repository.refreshSessions();
      await _pumpChat(
        tester,
        repository,
        size: const Size(1180, 800),
        desktopLayout: true,
      );

      final position = tester
          .widget<ChatAnimatedList>(find.byType(ChatAnimatedList))
          .scrollController!
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
      final expandButton = find.byKey(
        const Key('demo-inline-text-expand-long-text'),
      );
      final pixelsBeforeExpand = position.pixels;
      final maxBeforeExpand = position.maxScrollExtent;

      final expandRect = tester.getRect(expandButton);
      await tester.tapAt(Offset(expandRect.center.dx, expandRect.top + 6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('demo-inline-text-chunk-long-text-0')),
        findsOneWidget,
      );
      expect(position.maxScrollExtent, greaterThan(maxBeforeExpand));
      expect(position.pixels, closeTo(pixelsBeforeExpand, 1));
      final pixelsBeforeCollapse = position.pixels;

      tester.widget<TextButton>(expandButton).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        position.pixels,
        closeTo(pixelsBeforeCollapse.clamp(0, position.maxScrollExtent), 1),
      );
    },
  );

  testWidgets('duplicate failed text loads show one page-level toast', (
    tester,
  ) async {
    api.messages = [
      _message('failure-a', text: '失败文本 A', assetIds: const ['fail-text']),
      _message('failure-b', text: '失败文本 B', assetIds: const ['fail-text']),
    ];
    repository.dispose();
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    repository = _InlineChatRepository(storage, api)..restore();
    await repository.refreshSessions();
    await _pumpChat(tester, repository);

    expect(repository.failedTextReads, 2);
    repository.failedText!.completeError(StateError('offline'));
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 1),
    );

    expect(find.text('文件加载失败，请稍后重新打开'), findsOneWidget);
    expect(
      find.byKey(const Key('demo-inline-text-download-fail-text')),
      findsNWidgets(2),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpChat(
  WidgetTester tester,
  DemoRepository repository, {
  Size size = const Size(390, 844),
  bool desktopLayout = false,
}) async {
  tester.view.physicalSize = size;
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
            sessionId: 'inline-session',
            desktopLayout: desktopLayout,
          ),
        ),
      ),
    ),
  );
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final class _InlineChatRepository extends DemoRepository {
  _InlineChatRepository(super.storage, super.api)
    : super.harness(pollInterval: Duration.zero, maxPollAttempts: 0);

  @override
  Future<void> resumeHarnessSession(String id) async {}

  Completer<String>? failedText;
  int failedTextReads = 0;

  @override
  Future<String> readAssetText(DemoAsset asset) {
    if (asset.id == 'fail-text') {
      failedTextReads += 1;
      return (failedText ??= Completer<String>()).future;
    }
    return Future.value(
      asset.id == 'long-text'
          ? '${List.filled(900, '展开后保留的长正文。').join()}结尾'
          : '聊天内联正文',
    );
  }

  @override
  Future<Uint8List> readAssetBytes(DemoAsset asset) async =>
      Uint8List.fromList(List.filled(asset.sizeBytes, 0x41));
}

final class _InlineChatApi extends NetworkAgentApi {
  _InlineChatApi(super.dio);

  List<Map<String, Object?>> messages = [
    _message(
      'text-message',
      text: '这里是产物',
      assetIds: const ['script-txt', 'script-md'],
    ),
    _message(
      'image-message',
      text: '图片保持原批次',
      assetIds: const ['image-a', 'image-b'],
    ),
    _message('pdf-message', text: 'PDF 保持卡片', assetIds: const ['document-pdf']),
  ];

  Map<String, dynamic> snapshot() => {
    'session': _session,
    'lastSeq': 1,
    'messages': messages,
    'assets': _assets,
    'mediaJobs': <Object?>[],
    'runs': <Object?>[],
  };

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': _assets};

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [_session],
    'pageInfo': {'page': 1, 'pageSize': 20, 'pageCount': 1, 'total': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => snapshot();
}

Map<String, Object?> _message(
  String id, {
  required String text,
  List<String> assetIds = const [],
}) => {
  'id': id,
  'role': 'assistant',
  'memberId': 'popi',
  'text': text,
  'assetIds': assetIds,
  'status': 'completed',
  'createdAt': '2026-10-27T00:00:00.000Z',
};

const _session = <String, Object?>{
  'id': 'inline-session',
  'title': 'POPi',
  'kind': 'conversation',
  'revision': 1,
  'createdAt': '2026-10-27T00:00:00.000Z',
  'updatedAt': '2026-10-27T00:00:00.000Z',
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

const _digest =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

final _assets = <Map<String, Object?>>[
  _assetRecord(
    'script-txt',
    title: '同一原稿.txt',
    kind: 'script',
    mimeType: 'text/plain',
    sizeBytes: 18,
    sha256: _digest,
  ),
  _assetRecord(
    'script-md',
    title: '同一原稿.md',
    kind: 'script',
    mimeType: 'text/markdown',
    sizeBytes: 18,
    sha256: _digest,
  ),
  _assetRecord(
    'long-text',
    title: '长正文.txt',
    kind: 'script',
    mimeType: 'text/plain',
    sizeBytes: 100,
  ),
  _assetRecord(
    'fail-text',
    title: '共享失败.txt',
    kind: 'script',
    mimeType: 'text/plain',
    sizeBytes: 100,
    sha256: _digest,
  ),
  _assetRecord(
    'document-pdf',
    title: '说明.pdf',
    kind: 'script',
    mimeType: 'application/pdf',
    sizeBytes: 100,
    document: const {'format': 'pdf', 'status': 'ready'},
  ),
  _assetRecord(
    'image-a',
    title: '图片 A',
    kind: 'image',
    mimeType: 'image/png',
    sizeBytes: 100,
    width: 800,
    height: 600,
  ),
  _assetRecord(
    'image-b',
    title: '图片 B',
    kind: 'image',
    mimeType: 'image/png',
    sizeBytes: 100,
    width: 800,
    height: 600,
  ),
];

Map<String, Object?> _assetRecord(
  String id, {
  required String title,
  required String kind,
  required String mimeType,
  required int sizeBytes,
  String sha256 = '',
  int width = 0,
  int height = 0,
  Map<String, Object?>? document,
}) => {
  'id': id,
  'title': title,
  'kind': kind,
  'mimeType': mimeType,
  'sizeBytes': sizeBytes,
  'sha256': sha256,
  'width': width,
  'height': height,
  'contentUrl': '/api_agent/v2/assets/$id/content',
  'sessionId': 'inline-session',
  if (document != null) 'document': document,
};
