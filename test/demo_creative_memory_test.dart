import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
  });

  test(
    'creative memory survives JSON and local persistence with legacy defaults',
    () async {
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);

      await repository.updateSession(
        'inspiration',
        (session) => session.copyWith(
          creativeMemory: const DemoCreativeMemory(source: 'user'),
        ),
      );

      final restored = DemoRepository(storage)..restore();
      addTearDown(restored.dispose);
      expect(restored.session('inspiration').creativeMemory.text, isEmpty);
      expect(restored.session('inspiration').creativeMemory.source, 'user');

      final json = Map<String, Object?>.from(
        restored.session('inspiration').toJson(),
      )..remove('creativeMemory');
      final legacy = DemoSession.fromJson(json);
      expect(legacy.creativeMemory.text, isEmpty);
      expect(legacy.creativeMemory.source, 'ai');
    },
  );

  test(
    'Harness snapshots and PATCHes keep creative memory authoritative',
    () async {
      await DemoRepository.prepareHarnessStorage(storage);
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final api = _CreativeMemoryHarnessApi(dio);
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);

      await repository.refreshSessions();
      expect(
        repository.session('memory-session').creativeMemory.text,
        'AI 整理的初始记忆',
      );
      expect(repository.session('memory-session').creativeMemory.source, 'ai');

      api.authoritativeText = '服务端规范化后的手动记忆';
      await repository.updateSession(
        'memory-session',
        (session) => session.copyWith(
          creativeMemory: const DemoCreativeMemory(
            text: '客户端提交的手动记忆',
            source: 'user',
          ),
        ),
      );
      expect(api.patchCalls, 1);
      expect(api.lastExpectedConfigRevision, 3);
      expect(api.lastCreativeMemory, {'text': '客户端提交的手动记忆', 'source': 'user'});
      expect(
        repository.session('memory-session').creativeMemory.text,
        '服务端规范化后的手动记忆',
      );

      api
        ..authoritativeText = null
        ..configuration = _harnessConfiguration(
          creativeMemory: const DemoCreativeMemory(text: '下一次快照中的 AI 记忆'),
        )
        ..configRevision += 1
        ..serverRevision += 1;
      await repository.refreshSessions();
      expect(
        repository.session('memory-session').creativeMemory.text,
        '下一次快照中的 AI 记忆',
      );
      expect(repository.session('memory-session').creativeMemory.source, 'ai');

      await repository.updateSession(
        'memory-session',
        (session) => session.copyWith(
          creativeMemory: const DemoCreativeMemory(source: 'user'),
        ),
      );
      expect(api.lastCreativeMemory, {'text': '', 'source': 'user'});
      final restarted = DemoRepository.harness(storage, api)..restore();
      addTearDown(restarted.dispose);
      expect(restarted.session('memory-session').creativeMemory.text, isEmpty);
      expect(restarted.session('memory-session').creativeMemory.source, 'user');
    },
  );

  testWidgets('creative memory card edits and protects the whole paragraph', (
    tester,
  ) async {
    final repository = DemoRepository(storage)..restore();
    addTearDown(repository.dispose);
    const original = '画面保持暖色、自然光和生活纪录感。图片使用系统推荐模型，比例为 3:4；视频比例为 9:16。';
    await repository.updateSession(
      'inspiration',
      (session) => session.copyWith(
        creativeMemory: const DemoCreativeMemory(text: original),
      ),
    );
    await _pumpSettings(tester, repository);

    final card = find.byKey(const Key('demo-creative-memory-card'));
    await tester.scrollUntilVisible(card, 180, scrollable: _infoScrollable());
    expect(find.text(original), findsOneWidget);
    final background = tester.widget<Container>(
      find.byKey(const Key('demo-creative-memory-background')),
    );
    expect(
      (background.decoration! as BoxDecoration).color,
      const Color(0xFFF3F0FA),
    );

    await tester.tap(find.byKey(const Key('demo-creative-memory-edit')));
    await tester.pumpAndSettle();
    const edited = '画面清透、自然光。图片沿用当前可用模型，比例 1:1；视频沿用当前可用模型，比例 9:16。';
    await tester.enterText(
      find.byKey(const Key('demo-creative-memory-input')),
      edited,
    );
    await tester.tap(find.byKey(const Key('demo-creative-memory-confirm')));
    await tester.pumpAndSettle();

    final memory = repository.session('inspiration').creativeMemory;
    expect(memory.text, edited);
    expect(memory.source, 'user');
    expect(find.text(edited), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed creative memory save keeps the user input', (
    tester,
  ) async {
    final repository = _FailingCreativeMemoryRepository(storage)..restore();
    addTearDown(repository.dispose);
    await _pumpSettings(tester, repository);

    final card = find.byKey(const Key('demo-creative-memory-card'));
    await tester.scrollUntilVisible(card, 180, scrollable: _infoScrollable());
    await tester.tap(find.byKey(const Key('demo-creative-memory-edit')));
    await tester.pumpAndSettle();
    repository.failWrites = true;
    const draft = '用户尚未保存的创作记忆';
    await tester.enterText(
      find.byKey(const Key('demo-creative-memory-input')),
      draft,
    );
    await tester.tap(find.byKey(const Key('demo-creative-memory-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-creative-memory-input')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('demo-creative-memory-input')),
          )
          .controller!
          .text,
      draft,
    );
    expect(find.text('本地保存失败，请再次操作'), findsOneWidget);
    expect(repository.session('inspiration').creativeMemory.text, isEmpty);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('creative memory background follows dark theme', (tester) async {
    final repository = DemoRepository(storage)..restore();
    addTearDown(repository.dispose);
    await _pumpSettings(tester, repository, dark: true);

    final card = find.byKey(const Key('demo-creative-memory-card'));
    await tester.scrollUntilVisible(card, 180, scrollable: _infoScrollable());
    final background = tester.widget<Container>(
      find.byKey(const Key('demo-creative-memory-background')),
    );
    expect(
      (background.decoration! as BoxDecoration).color,
      isNot(const Color(0xFFF3F0FA)),
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _infoScrollable() => find
    .descendant(
      of: find.byKey(const PageStorageKey('demo-settings-info')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _pumpSettings(
  WidgetTester tester,
  DemoRepository repository, {
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ToastificationWrapper(
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DemoSettingsPage(
          repository: repository,
          sessionId: 'inspiration',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FailingCreativeMemoryRepository extends DemoRepository {
  _FailingCreativeMemoryRepository(super.storage);

  bool failWrites = false;

  @override
  Future<void> updateSession(
    String id,
    DemoSession Function(DemoSession) update,
  ) async {
    if (failWrites) throw StateError('save failed');
    return super.updateSession(id, update);
  }
}

class _CreativeMemoryHarnessApi extends NetworkAgentApi {
  _CreativeMemoryHarnessApi(super.dio);

  Map<String, Object?> configuration = _harnessConfiguration(
    creativeMemory: const DemoCreativeMemory(text: 'AI 整理的初始记忆'),
  );
  int configRevision = 3;
  int serverRevision = 5;
  int patchCalls = 0;
  int? lastExpectedConfigRevision;
  Map<String, Object?>? lastCreativeMemory;
  String? authoritativeText;

  Map<String, Object?> get _record => {
    'id': 'memory-session',
    'title': '创作会话',
    'kind': 'conversation',
    'revision': serverRevision,
    'createdAt': '2026-10-25T00:00:00.000Z',
    'updatedAt': '2026-10-25T00:00:00.000Z',
    'archived': false,
    'bindingStatus': 'ready',
    'configuration': configuration,
    'configurationStatus': 'configured',
    'configRevision': configRevision,
    'pinned': false,
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
    'pageInfo': {
      'page': page,
      'pageSize': pageSize,
      'pageCount': 1,
      'total': 1,
    },
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => {
    'session': _record,
    'lastSeq': 0,
    'messages': <Object?>[],
    'runs': <Object?>[],
    'assets': <Object?>[],
    'mediaJobs': <Object?>[],
  };

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
  }) async {
    patchCalls += 1;
    lastExpectedConfigRevision = expectedConfigRevision;
    if (configuration != null) {
      final requestedMemory = Map<String, Object?>.from(
        configuration['creativeMemory'] as Map,
      );
      lastCreativeMemory = requestedMemory;
      this.configuration = {
        ...configuration,
        'creativeMemory': {
          ...requestedMemory,
          if (authoritativeText != null) 'text': authoritativeText!,
        },
      };
      configRevision += 1;
    }
    serverRevision += 1;
    return Map<String, dynamic>.from(_record);
  }
}

Map<String, Object?> _harnessConfiguration({
  DemoCreativeMemory creativeMemory = const DemoCreativeMemory(),
}) => {
  'members': ['popi'],
  'roles': <String>[],
  'capabilities': DemoSession.defaultCapabilities,
  'memberCapabilities': {'popi': DemoSession.defaultCapabilities},
  'memberNames': <String, String>{},
  'memberInstructions': <String, String>{},
  'memberAvatars': <String, String>{},
  'memberColors': <String, int>{},
  'workMode': 'onDemand',
  'activeMemberId': 'popi',
  'direction': '',
  'positioning': '',
  'accountPreferences': <String, String>{},
  'creativeMemory': creativeMemory.toJson(),
  'roleProfiles': <String, Object?>{},
};
