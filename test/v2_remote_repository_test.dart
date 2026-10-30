import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_remote_repository.dart';
import 'package:popi_ai_app/features/v2_shared/domain/v2_models.dart';
import 'package:popi_ai_app/features/v2_shared/domain/v2_upload_file.dart';
import 'package:popi_ai_app/features/v2_session/presentation/v2_chat_controller.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations_en.dart';

typedef _Reply = FutureOr<Object> Function(RequestOptions);

class _Server {
  final requests = <RequestOptions>[];
  late _Reply reply = _default;
  Map<String, Object?> record = {
    'id': 'session',
    'title': 'Saved session',
    'kind': 'project',
    'revision': 1,
    'configRevision': 1,
    'configurationStatus': 'configured',
    'configuration': {
      'members': ['popi', 'writer'],
      'roles': <String>[],
      'capabilities': ['image', 'script'],
      'memberCapabilities': {
        'popi': ['image'],
        'writer': ['script'],
      },
      'memberSkills': {'writer': <String>[]},
      'memberBotIds': {'popi': 'bot:my-assistant', 'writer': 'builtin:writer'},
      'memberNames': {'writer': 'Writer'},
      'creativeMemory': {'text': 'Remember the cast', 'source': 'user'},
      'accountPreferences': {'feeling': 'Warm'},
    },
  };
  late final dio = Dio(BaseOptions(baseUrl: 'https://agent.example'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          try {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: await reply(options),
              ),
            );
          } catch (error) {
            handler.reject(
              error is DioException
                  ? error
                  : DioException(requestOptions: options, error: error),
            );
          }
        },
      ),
    );
  Object snapshot({
    int revision = 1,
    int seq = 1,
    String text = 'Reply',
    List<Object> runs = const [],
    List<Object> messages = const [],
  }) => {
    'session': {...record, 'revision': revision},
    'lastSeq': seq,
    'messages': messages.isNotEmpty
        ? messages
        : [
            {
              'id': 'assistant',
              'role': 'assistant',
              'text': text,
              'status': 'completed',
            },
          ],
    'runs': runs,
  };
  Object _default(RequestOptions o) {
    if (o.path.endsWith('/snapshot')) return snapshot();
    if (o.path.endsWith('/messages')) {
      return {'runId': 'run', 'state': 'queued'};
    }
    if (o.path.endsWith('/assets') || o.path.endsWith('/roles')) {
      return {'list': [], 'total': 0};
    }
    if (o.path.endsWith('/sessions') && o.method == 'GET') {
      return {
        'list': [record],
        'pageInfo': {'pageCount': 1},
      };
    }
    if (o.method == 'PATCH') {
      final data = Map<String, Object?>.from(o.data as Map);
      record = {
        ...record,
        if (data['title'] != null) 'title': data['title'],
        if (data['configuration'] != null)
          'configuration': data['configuration'],
        'configRevision': 2,
        'revision': 2,
      };
      return record;
    }
    return {};
  }
}

void main() {
  late PreferencesStorage storage;
  late _Server server;
  late V2RemoteRepository repository;
  V2RemoteRepository create({String owner = 'one', NetworkApi? library}) =>
      V2RemoteRepository(
        storage,
        NetworkAgentApi(server.dio),
        ownerId: owner,
        namespace: 'test:$owner',
        mediaHeaders: (_) => {},
        libraryApi: library ?? NetworkApi(server.dio),
        pollInterval: const Duration(days: 1),
      )..restore();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    server = _Server();
    repository = create();
  });
  tearDown(() {
    repository.dispose();
    server.dio.close(force: true);
  });

  test(
    'starts empty, loads owned sessions, restores completion per account',
    () async {
      expect(repository.sessions, isEmpty);
      expect(repository.assets, isEmpty);
      expect(repository.hasCompletedOnboarding('one'), isFalse);
      await repository.refresh();
      expect(repository.sessions.single.title, 'Saved session');
      expect(repository.hasCompletedOnboarding('one'), isTrue);
      final restored = create();
      final other = create(owner: 'two');
      addTearDown(restored.dispose);
      addTearDown(other.dispose);
      expect(restored.hasCompletedOnboarding('one'), isTrue);
      expect(other.hasCompletedOnboarding('two'), isFalse);
    },
  );

  test('archived sessions skip the guide on a fresh device', () async {
    server.reply = (o) => {
      'list': o.queryParameters['archived'] == 'true' ? [server.record] : [],
      'pageInfo': {'pageCount': 1},
    };
    await repository.refresh();
    expect(repository.sessions, isEmpty);
    expect(repository.hasCompletedOnboarding('one'), isTrue);
  });

  test(
    'failed initial load leaves onboarding undecided and no fixture data',
    () async {
      server.reply = (_) => throw StateError('Offline');
      await expectLater(repository.refresh(), throwsA(isA<DioException>()));
      expect(repository.hasCompletedOnboarding('one'), isFalse);
      expect(repository.sessions, isEmpty);
    },
  );

  test(
    'guide sends all choices once with stable ID and survives deletion',
    () async {
      server.reply = (o) {
        if (o.method == 'POST') {
          return {
            ...server.record,
            'id': 'first',
            'configuration': (o.data as Map)['configuration'],
          };
        }
        return <String, Object?>{};
      };
      final profile = {
        'contentDirections': ['Campus'],
        'audienceFeelings': ['Warm'],
        'presentationFormats': ['3D'],
        'creativeConstraints': ['Short film'],
        'targetAudience': ['Students'],
      };
      Future<String> confirm() => repository.completeOnboarding(
        userId: 'one',
        requestId: 'stable',
        title: 'My account',
        profile: profile,
      );
      expect(await confirm(), 'first');
      expect(await confirm(), 'first');
      final posts = server.requests.where((r) => r.method == 'POST').toList();
      expect(posts, hasLength(1));
      expect((posts.single.data as Map)['clientRequestId'], 'stable');
      final c = (posts.single.data as Map)['configuration'] as Map;
      expect(c['direction'], 'Campus');
      expect(c['positioning'], '3D');
      expect(c['accountPreferences'], {
        'feeling': 'Warm',
        'format': 'Short film',
        'audience': 'Students',
      });
      await repository.deleteSession('first');
      expect(repository.sessions, isEmpty);
      expect(repository.hasCompletedOnboarding('one'), isTrue);
    },
  );

  test(
    'PATCH keeps unedited configuration and removes unselected members',
    () async {
      await repository.refresh();
      await repository.updateSession(
        'session',
        (s) => s.copyWith(members: ['popi'], direction: 'Stories'),
      );
      final request = server.requests.last;
      final body = request.data as Map;
      expect(body['expectedConfigRevision'], 1);
      final c = body['configuration'] as Map;
      expect(c['creativeMemory'], {
        'text': 'Remember the cast',
        'source': 'user',
      });
      expect(c['memberBotIds'], {'popi': 'bot:my-assistant'});
      expect(c['memberNames'], isEmpty);
      expect(c['memberCapabilities'], {
        'popi': ['image'],
      });
      expect(repository.session('session').direction, 'Stories');
    },
  );

  test(
    'global capability toggles update execution member capabilities',
    () async {
      await repository.refresh();
      await repository.updateSession(
        'session',
        (s) => s.copyWith(capabilities: ['image', 'video']),
      );
      expect(
        ((server.requests.last.data as Map)['configuration']
            as Map)['memberCapabilities'],
        {
          'popi': ['image', 'video'],
          'writer': ['image', 'video'],
        },
      );
    },
  );

  test(
    'configuration conflict refreshes authority and surfaces failure',
    () async {
      await repository.refresh();
      server.reply = (o) {
        if (o.method == 'PATCH') {
          throw DioException(
            requestOptions: o,
            response: Response(
              requestOptions: o,
              statusCode: 409,
              data: {'code': 'config_conflict', 'message': 'Changed elsewhere'},
            ),
          );
        }
        return server.snapshot(revision: 4, seq: 4);
      };
      await expectLater(
        repository.updateSession(
          'session',
          (s) => s.copyWith(direction: 'Draft'),
        ),
        throwsA(isA<AgentApiException>()),
      );
      expect(repository.session('session').serverRevision, 4);
      expect(repository.session('session').direction, isEmpty);
    },
  );

  test('out of order snapshots cannot replace newer messages', () async {
    await repository.refresh();
    final first = Completer<Object>();
    var calls = 0;
    server.reply = (_) => calls++ == 0
        ? first.future
        : server.snapshot(revision: 3, seq: 3, text: 'New');
    final old = repository.refreshSession('session');
    await Future<void>.delayed(Duration.zero);
    await repository.refreshSession('session');
    first.complete(server.snapshot(revision: 2, seq: 2, text: 'Old'));
    await old;
    expect(repository.session('session').messages.single.text, 'New');
  });

  test('PATCH response cannot overwrite a newer snapshot', () async {
    await repository.refresh();
    final patch = Completer<Object>();
    server.reply = (o) => o.method == 'PATCH'
        ? patch.future
        : server.snapshot(revision: 5, seq: 5, text: 'Latest');
    final edit = repository.updateSession(
      'session',
      (s) => s.copyWith(title: 'Rename'),
    );
    await Future<void>.delayed(Duration.zero);
    await repository.refreshSession('session');
    patch.complete({...server.record, 'revision': 2});
    await edit;
    expect(repository.session('session').messages.single.text, 'Latest');
    expect(repository.session('session').serverRevision, 5);
  });

  test(
    'message acceptance succeeds even when the following snapshot fails',
    () async {
      await repository.refresh();
      server.reply = (o) => o.path.endsWith('/messages')
          ? {'runId': 'run'}
          : throw StateError('Offline');
      final controller = V2ChatController(repository, 'session');
      addTearDown(controller.dispose);
      expect(
        await controller.send('Create an image', [], AppLocalizationsEn()),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repository.session('session').running, isTrue);
      expect(
        server.requests.where((o) => o.path.endsWith('/messages')),
        hasLength(1),
      );
      expect(repository.syncError, isNotNull);
    },
  );

  test(
    'uncertain submission retries reuse ID but a later identical send gets a new ID',
    () async {
      await repository.refresh();
      var fail = true;
      server.reply = (o) {
        if (o.path.endsWith('/messages')) {
          if (fail) throw StateError('Connection lost');
          return {'runId': 'run'};
        }
        return server.snapshot(
          runs: [
            {'id': 'run', 'state': 'completed'},
          ],
        );
      };
      await expectLater(
        repository.sendMessage('session', 'hello', []),
        throwsA(isA<DioException>()),
      );
      fail = false;
      await repository.sendMessage('session', 'hello', []);
      await repository.sendMessage('session', 'hello', []);
      final ids = server.requests
          .where((o) => o.path.endsWith('/messages'))
          .map((o) => (o.data as Map)['clientRequestId'])
          .toList();
      expect(ids[0], ids[1]);
      expect(ids[2], isNot(ids[1]));
    },
  );

  test('list refresh preserves the active task stop restriction', () async {
    await repository.refresh();
    server.reply = (o) => o.path.endsWith('/messages')
        ? {'runId': 'run', 'jobId': 'film'}
        : server._default(o);
    await repository.sendMessage('session', 'Create a film', []);
    expect(repository.session('session').canStop, isFalse);
    await repository.refresh();
    expect(repository.session('session').running, isTrue);
    expect(repository.session('session').canStop, isFalse);
  });

  test('question responds with revision and retains stable retry ID', () async {
    await repository.refresh();
    const question = V2Question(
      id: 'q1',
      revision: 2,
      status: 'pending',
      questions: [V2QuestionField(id: 'tone', question: 'Tone?')],
    );
    server.reply = (o) => o.path.endsWith('/snapshot')
        ? server.snapshot(
            messages: [
              {
                'id': 'q',
                'role': 'assistant',
                'text': '',
                'question': question.toJson(),
              },
            ],
            runs: [
              {'id': 'run', 'state': 'waiting_user'},
            ],
          )
        : <String, Object?>{};
    await repository.refreshSession('session');
    expect(repository.session('session').running, isTrue);
    await repository.respondQuestion('session', question, 'submit', {
      'tone': 'Warm',
    });
    final body =
        server.requests.firstWhere((o) => o.path.endsWith('/respond')).data
            as Map;
    expect(body['revision'], 2);
    expect(body['answer'], {'tone': 'Warm'});
  });

  test('direct upload uses library lease and imports once on repeat', () async {
    final bytes = Uint8List.fromList(utf8.encode('A script'));
    final file = V2UploadFile.fromBytes(
      name: 'script.txt',
      mimeType: 'text/plain',
      bytes: bytes,
    );
    server.reply = (o) {
      if (o.path.contains('/uploads/')) {
        return {
          'upload': {'id': 'lease', 'state': 'ready', 'assetId': 'business'},
        };
      }
      return {
        'asset': {
          'id': 'asset',
          'kind': 'script',
          'title': file.name,
          'contentUrl': '/api_agent/v2/assets/asset/content',
          'mimeType': file.mimeType,
          'sizeBytes': bytes.length,
          'businessAssetId': 'business',
        },
      };
    };
    final first = await repository.uploadFile(file);
    expect((await repository.uploadFile(file)).id, first.id);
    expect(repository.assets, hasLength(1));
    expect(server.requests.map((o) => o.path), [
      '/api_client/asset-library/uploads/create',
      '/api_agent/v2/assets/import',
    ]);
  });

  test('foreign content URL is rejected before rendering', () async {
    server.reply = (_) => {
      'list': [
        {
          'id': 'asset',
          'kind': 'image',
          'title': 'Image',
          'contentUrl': 'https://other.example/secret',
        },
      ],
    };
    await expectLater(repository.refreshAssets(), throwsFormatException);
    expect(repository.assets, isEmpty);
  });

  test('pending requests cannot mutate disposed account state', () async {
    await repository.refresh();
    final pending = Completer<Object>();
    server.reply = (_) => pending.future;
    final old = repository.refreshSession('session');
    repository.dispose();
    repository = create(owner: 'two');
    pending.complete(server.snapshot(text: 'Previous account'));
    await expectLater(old, throwsStateError);
    expect(repository.sessions, isEmpty);
  });
}
