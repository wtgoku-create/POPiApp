import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emptySnapshot = '{"sessions":[],"assets":[]}';
const _horseAvatar = 'assets/animations/bot_avatars/horse.png';
const _snakeAvatar = 'assets/animations/bot_avatars/snake.png';

void main() {
  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      DemoRepository.storageKey: _emptySnapshot,
      DemoRepository.harnessStorageKey: _emptySnapshot,
    });
    storage = PreferencesStorage(await SharedPreferences.getInstance());
  });

  test(
    'all session kinds default to one fully capable POPi assistant',
    () async {
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);

      for (final kind in DemoSessionKind.values) {
        final id = await repository.createSession('Default ${kind.name}', kind);
        final session = repository.session(id);

        expect(session.members, ['popi']);
        expect(session.activeMemberId, 'popi');
        expect(session.roles, isEmpty);
        expect(session.messages, isEmpty);
        expect(session.capabilities, DemoSession.defaultCapabilities);
        expect(
          session.capabilitiesFor('popi'),
          DemoSession.defaultCapabilities,
        );
      }

      expect(repository.assistantProfiles.map((profile) => profile.id), [
        'builtin:popi',
        'builtin:designer',
        'builtin:writer',
        'builtin:director',
        'builtin:sound',
      ]);
    },
  );

  test(
    'partial custom profile is persisted and restored without defaults',
    () async {
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);
      const assistant = DemoAssistantProfile(
        id: 'draft:horse',
        memberId: 'sound',
        name: '  午后声音  ',
        avatarAsset: _horseAvatar,
      );

      final id = await repository.createSession(
        '声音会话',
        DemoSessionKind.conversation,
        assistant: assistant,
      );
      final created = repository.session(id);
      expect(created.memberNames, {'sound': '午后声音'});
      expect(created.memberAvatars, {'sound': _horseAvatar});
      expect(created.memberInstructions, isEmpty);
      expect(created.memberColors, isEmpty);

      final restored = DemoRepository(storage)..restore();
      addTearDown(restored.dispose);
      final profile = restored.assistantProfiles.singleWhere(
        (candidate) => candidate.name == '午后声音',
      );
      expect(profile.memberId, 'sound');
      expect(profile.avatarAsset, _horseAvatar);
      expect(profile.instructions, isEmpty);
      expect(profile.avatarColor, isNull);
    },
  );

  test(
    'saved identity is deduplicated and copied into isolated sessions',
    () async {
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);
      const assistant = DemoAssistantProfile(
        id: 'draft:director',
        memberId: 'director',
        name: '分镜搭档',
        instructions: '先整理镜头，再生成画面。',
        avatarAsset: _snakeAvatar,
        avatarColor: 0xFF7655EE,
      );

      final sourceId = await repository.createSession(
        '来源',
        DemoSessionKind.conversation,
        assistant: assistant,
      );
      await repository.createSession(
        '重复资料',
        DemoSessionKind.workflow,
        assistant: assistant,
      );
      final saved = repository.assistantProfiles
          .where((profile) => !profile.isBuiltIn && profile.name == '分镜搭档')
          .single;

      final copyId = await repository.createSession(
        '独立副本',
        DemoSessionKind.project,
        assistant: saved,
      );
      await repository.updateSession(
        sourceId,
        (session) => session.copyWith(
          memberNames: const {'director': '已修改来源'},
          messages: const [DemoMessage(id: 'm1', text: '来源历史')],
        ),
      );

      final copy = repository.session(copyId);
      expect(copy.memberNames, {'director': '分镜搭档'});
      expect(copy.memberInstructions, {'director': '先整理镜头，再生成画面。'});
      expect(copy.memberAvatars, {'director': _snakeAvatar});
      expect(copy.memberColors, {'director': 0xFF7655EE});
      expect(copy.messages, isEmpty);
      expect(copy.roles, isEmpty);
    },
  );

  test(
    'assistant profile rejects an unknown avatar and member mismatch',
    () async {
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);

      await expectLater(
        repository.createSession(
          'Invalid avatar',
          DemoSessionKind.conversation,
          assistant: const DemoAssistantProfile(
            id: 'invalid-avatar',
            memberId: 'popi',
            avatarAsset: 'assets/images/not-a-zodiac.png',
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.createSession(
          'Mismatched member',
          DemoSessionKind.conversation,
          members: const ['writer'],
          assistant: const DemoAssistantProfile(
            id: 'mismatch',
            memberId: 'sound',
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Harness creation sends the complete assistant configuration once',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final api = _RecordingHarnessApi(dio);
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      const assistant = DemoAssistantProfile(
        id: 'draft:writer',
        memberId: 'writer',
        name: '文案助手',
        instructions: '保持简洁。',
        avatarAsset: _horseAvatar,
        avatarColor: 0xFF123456,
      );

      await repository.createSession(
        '一次创建',
        DemoSessionKind.workflow,
        assistant: assistant,
      );

      expect(api.creates, hasLength(1));
      expect(api.updateCalls, 0);
      final request = api.creates.single;
      expect(request.title, '一次创建');
      expect(request.kind, 'workflow');
      expect(request.configuration, {
        'members': ['writer'],
        'roles': <String>[],
        'capabilities': DemoSession.defaultCapabilities,
        'memberCapabilities': {'writer': DemoSession.defaultCapabilities},
        'memberNames': {'writer': '文案助手'},
        'memberInstructions': {'writer': '保持简洁。'},
        'memberAvatars': {'writer': _horseAvatar},
        'memberColors': {'writer': 0xFF123456},
        'workMode': 'onDemand',
        'activeMemberId': 'writer',
        'direction': '',
        'positioning': '',
        'accountPreferences': <String, String>{},
        'roleProfiles': <String, Object?>{},
      });
    },
  );

  test(
    'Harness retry reuses identity while changed assistant gets a new one',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final api = _RecordingHarnessApi(dio)..failCreates = 1;
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      const first = DemoAssistantProfile(
        id: 'draft:first',
        memberId: 'designer',
        name: '造型师',
        avatarAsset: _horseAvatar,
      );

      await expectLater(
        repository.createSession(
          '同名会话',
          DemoSessionKind.conversation,
          assistant: first,
        ),
        throwsA(isA<DioException>()),
      );
      await repository.createSession(
        '同名会话',
        DemoSessionKind.conversation,
        assistant: first,
      );
      await repository.createSession(
        '同名会话',
        DemoSessionKind.conversation,
        assistant: first.copyWith(
          id: 'draft:changed',
          name: '新造型师',
          avatarAsset: _snakeAvatar,
        ),
      );

      expect(api.creates, hasLength(3));
      expect(api.creates[1].clientRequestId, api.creates[0].clientRequestId);
      expect(
        api.creates[2].clientRequestId,
        isNot(api.creates[1].clientRequestId),
      );
    },
  );
}

typedef _CreateRequest = ({
  String clientRequestId,
  String title,
  String kind,
  Map<String, Object?> configuration,
});

class _RecordingHarnessApi extends NetworkAgentApi {
  _RecordingHarnessApi(super.dio);

  final List<_CreateRequest> creates = [];
  int updateCalls = 0;
  int failCreates = 0;
  int _created = 0;

  @override
  Future<Map<String, dynamic>> createHarnessSession({
    required String clientRequestId,
    required String title,
    required String kind,
    Map<String, Object?>? configuration,
    CancelToken? cancelToken,
  }) async {
    final captured = Map<String, Object?>.from(configuration ?? const {});
    creates.add((
      clientRequestId: clientRequestId,
      title: title,
      kind: kind,
      configuration: captured,
    ));
    if (failCreates > 0) {
      failCreates -= 1;
      throw DioException(
        requestOptions: RequestOptions(path: '/api_agent/v2/sessions'),
        type: DioExceptionType.connectionError,
      );
    }
    _created += 1;
    return {
      'id': 'server-$_created',
      'title': title,
      'kind': kind,
      'revision': 1,
      'createdAt': '2026-10-24T00:00:00.000Z',
      'updatedAt': '2026-10-24T00:00:00.000Z',
      'archived': false,
      'bindingStatus': 'ready',
      'configuration': captured,
      'configurationStatus': 'configured',
      'configRevision': 1,
    };
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
  }) async {
    updateCalls += 1;
    return {'id': id};
  }
}
