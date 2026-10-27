import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
  });

  test(
    'offline sample batch rolls back a failed save and retries once',
    () async {
      final batchStorage = _BatchPreferences(storage.preferences);
      final repository = DemoRepository(batchStorage)..restore();
      addTearDown(repository.dispose);
      final originalIds = repository.assets.map((asset) => asset.id).toList();
      const selected = [
        DemoAssetKind.image,
        DemoAssetKind.audio,
        DemoAssetKind.script,
      ];
      batchStorage.fail = true;
      await expectLater(repository.importSamples(selected), throwsStateError);
      expect(repository.assets.map((asset) => asset.id), originalIds);
      expect(batchStorage.getString(DemoRepository.storageKey), isNull);
      batchStorage.fail = false;
      await repository.importSamples(selected);
      expect(batchStorage.writes, 2);
      expect(
        repository.assets,
        hasLength(originalIds.length + selected.length),
      );
      expect(
        repository.assets.take(selected.length).map((asset) => asset.kind),
        selected,
      );
      final restored = DemoRepository(batchStorage)..restore();
      addTearDown(restored.dispose);
      expect(
        restored.assets.map((asset) => asset.id),
        repository.assets.map((asset) => asset.id),
      );
    },
  );

  test(
    'session creation validates one to five Bots and persists their order',
    () async {
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);

      final oneId = await repository.createSession(
        'One Bot',
        DemoSessionKind.conversation,
        members: const ['sound'],
      );
      const allBots = ['sound', 'popi', 'director', 'writer', 'designer'];
      final fiveId = await repository.createSession(
        'Five Bots',
        DemoSessionKind.project,
        members: allBots,
      );

      expect(repository.session(oneId).members, ['sound']);
      expect(repository.session(fiveId).members, allBots);
      await expectLater(
        repository.createSession(
          'No Bot',
          DemoSessionKind.conversation,
          members: const [],
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.createSession(
          'Too many Bots',
          DemoSessionKind.conversation,
          members: const [
            'popi',
            'designer',
            'writer',
            'director',
            'sound',
            'popi',
          ],
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.createSession(
          'Unknown Bot',
          DemoSessionKind.conversation,
          members: const ['popi', 'unknown'],
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.createSession(
          'Duplicate Bot',
          DemoSessionKind.conversation,
          members: const ['popi', 'popi'],
        ),
        throwsArgumentError,
      );

      final restored = DemoRepository(storage)..restore();
      addTearDown(restored.dispose);
      expect(restored.session(oneId).members, ['sound']);
      expect(restored.session(fiveId).members, allBots);
    },
  );

  test('session preferences survive JSON round-trip with legacy defaults', () {
    const session = DemoSession(
      id: 'preferences',
      title: 'Preferences',
      kind: DemoSessionKind.workflow,
      members: ['popi', 'writer'],
      roles: [],
      messages: [],
      memberCapabilities: {
        'popi': ['image', 'video'],
        'writer': ['script'],
      },
      workMode: 'automatic',
      pinned: true,
    );

    final decoded = DemoSession.fromJson(session.toJson());
    expect(decoded.memberCapabilities, {
      'popi': ['image', 'video'],
      'writer': ['script'],
    });
    expect(decoded.workMode, 'automatic');
    expect(decoded.pinned, isTrue);

    final legacyJson = Map<String, Object?>.from(session.toJson())
      ..remove('memberCapabilities')
      ..remove('workMode')
      ..remove('pinned');
    final legacy = DemoSession.fromJson(legacyJson);
    expect(legacy.memberCapabilities, isEmpty);
    expect(legacy.workMode, 'onDemand');
    expect(legacy.pinned, isFalse);
  });

  test(
    'pin ordering is stable and unpinning persists across restart',
    () async {
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);
      final originalOrder = repository.sessions
          .map((session) => session.id)
          .toList();

      await repository.updateSession(
        'old',
        (session) => session.copyWith(pinned: true),
      );
      await repository.updateSession(
        'alice',
        (session) => session.copyWith(pinned: true),
      );

      expect(repository.sessions.take(2).map((session) => session.id), [
        'alice',
        'old',
      ]);
      expect(
        repository.sessions.skip(2).map((session) => session.id),
        originalOrder.where((id) => id != 'alice' && id != 'old'),
      );

      await repository.updateSession(
        'alice',
        (session) => session.copyWith(pinned: false),
      );
      expect(repository.sessions.first.id, 'old');
      expect(
        repository.sessions.skip(1).map((session) => session.id),
        originalOrder.where((id) => id != 'old'),
      );

      final restored = DemoRepository(storage)..restore();
      addTearDown(restored.dispose);
      expect(restored.sessions.first.id, 'old');
      expect(restored.session('old').pinned, isTrue);
      expect(restored.session('alice').pinned, isFalse);
    },
  );

  test(
    'Harness saves preferences and configured server remains authoritative',
    () async {
      await DemoRepository.prepareHarnessStorage(storage);
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final api = _PreferencesHarnessApi(dio);
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);

      await repository.refreshSessions();
      await repository.updateSession(
        'server-session',
        (session) => session.copyWith(
          members: const ['writer', 'popi'],
          memberCapabilities: const {
            'writer': ['script'],
            'popi': ['image'],
          },
          workMode: 'manual',
          pinned: true,
        ),
      );

      expect(api.patchCalls, 1);
      expect(api.lastExpectedConfigRevision, 1);
      expect(api.lastPinned, isTrue);
      expect(api.lastConfiguration?['members'], ['writer', 'popi']);
      expect(api.lastConfiguration?['memberCapabilities'], {
        'writer': ['script'],
        'popi': ['image'],
      });
      expect(api.lastConfiguration?['workMode'], 'manual');

      api.title = 'Server renamed';
      await repository.refreshSessions();
      final refreshed = repository.session('server-session');
      expect(refreshed.title, 'Server renamed');
      expect(refreshed.members, ['writer', 'popi']);
      expect(refreshed.memberCapabilities, {
        'writer': ['script'],
        'popi': ['image'],
      });
      expect(refreshed.workMode, 'manual');
      expect(refreshed.pinned, isTrue);

      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      final persisted = restored.session('server-session');
      expect(persisted.members, ['writer', 'popi']);
      expect(persisted.memberCapabilities, refreshed.memberCapabilities);
      expect(persisted.workMode, 'manual');
      expect(persisted.pinned, isTrue);

      api.title = 'Server renamed again';
      await restored.refreshSessions();
      final restartedAndRefreshed = restored.session('server-session');
      expect(restartedAndRefreshed.title, 'Server renamed again');
      expect(restartedAndRefreshed.members, ['writer', 'popi']);
      expect(
        restartedAndRefreshed.memberCapabilities,
        refreshed.memberCapabilities,
      );
      expect(restartedAndRefreshed.workMode, 'manual');
      expect(restartedAndRefreshed.pinned, isTrue);

      api
        ..configuration = _serverConfiguration(
          members: const ['designer'],
          capabilities: const ['image'],
          memberCapabilities: const {
            'designer': ['image'],
          },
          workMode: 'automatic',
          activeMemberId: 'designer',
        )
        ..configRevision += 1
        ..serverRevision += 1
        ..pinned = false;
      await restored.refreshSessions();
      final authoritative = restored.session('server-session');
      expect(authoritative.members, ['designer']);
      expect(authoritative.memberCapabilities, {
        'designer': ['image'],
      });
      expect(authoritative.workMode, 'automatic');
      expect(authoritative.pinned, isFalse);
    },
  );
}

class _PreferencesHarnessApi extends NetworkAgentApi {
  _PreferencesHarnessApi(super.dio);

  String title = 'Server title';
  Map<String, Object?> configuration = _serverConfiguration();
  int configRevision = 1;
  int serverRevision = 1;
  bool pinned = false;
  int patchCalls = 0;
  Map<String, Object?>? lastConfiguration;
  int? lastExpectedConfigRevision;
  bool? lastPinned;

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};

  Map<String, Object?> get _record => {
    'id': 'server-session',
    'title': title,
    'kind': 'conversation',
    'revision': serverRevision,
    'createdAt': '2026-10-23T00:00:00.000Z',
    'updatedAt': '2026-10-23T00:00:00.000Z',
    'archived': false,
    'bindingStatus': 'ready',
    'configuration': configuration,
    'configurationStatus': 'configured',
    'configRevision': configRevision,
    'pinned': pinned,
  };

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
    lastConfiguration = configuration;
    lastExpectedConfigRevision = expectedConfigRevision;
    lastPinned = pinned;
    if (title != null) this.title = title;
    if (pinned != null) this.pinned = pinned;
    if (configuration != null) {
      this.configuration = configuration;
      configRevision += 1;
    }
    serverRevision += 1;
    return Map<String, dynamic>.from(_record);
  }
}

Map<String, Object?> _serverConfiguration({
  List<String> members = const ['popi'],
  List<String> capabilities = const ['character', 'script', 'image'],
  Map<String, List<String>> memberCapabilities = const {
    'popi': ['character', 'script', 'image'],
  },
  String workMode = 'onDemand',
  String activeMemberId = 'popi',
}) => {
  'members': members,
  'roles': <String>[],
  'capabilities': capabilities,
  'memberCapabilities': memberCapabilities,
  'memberNames': <String, String>{},
  'memberInstructions': <String, String>{},
  'memberAvatars': <String, String>{},
  'memberColors': <String, int>{},
  'workMode': workMode,
  'activeMemberId': activeMemberId,
  'direction': '',
  'positioning': '',
  'roleProfiles': <String, Object?>{},
};

class _BatchPreferences extends PreferencesStorage {
  _BatchPreferences(super.preferences);
  bool fail = false;
  int writes = 0;
  @override
  Future<void> setString(String key, String value) async {
    writes++;
    if (fail) throw StateError('local save failed');
    await super.setString(key, value);
  }
}
