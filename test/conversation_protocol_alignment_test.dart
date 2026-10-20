import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/config/app_config.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_creation.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_storyboard.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_generation.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/domain/conversation_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'conversation_events_test.dart'
    show chatId, chatEvent, chatMessageJson, chatSnapshotJson;

const _selection = ConversationGenerationSelection(
  config: HomeConfig(modelId: 'image-model', params: {'ratio': '16:9'}),
  estimatedPoints: 8,
  mediaPreferencesRevision: 2,
  roleTemplateId: '12',
  roleTemplateTitle: 'Line art',
  roleTemplateMediaId: '90',
  referenceMediaId: '91',
  requirements: 'Keep the original identity',
);

ConversationBlock _card({bool home = false}) => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'plan',
  'data': {
    'id': 'confirmation',
    'kind': 'generation',
    'status': 'ready',
    'revision': 1,
    'allowedActions': home ? [] : ['confirm', 'cancel'],
    if (home) 'homePlan': {} else 'roleImage': {'useProfile': true},
    'plan': {
      'items': [
        {
          'key': 'three_view',
          'mediaType': home ? 'video' : 'image',
          ..._selection.config.toJson(),
        },
      ],
    },
  },
});

Map<String, Object?> _configuredRequest() => {
  'method': 'POST',
  'path': '/api_client/agent/v2/generation/confirmations',
  'body': {
    'clientRequestId': 'business-confirmation',
    'input': {
      'creatorInputId': 'fixed-input',
      'item': {
        'key': 'three_view',
        'references': [
          {'mediaId': '90', 'purpose': 'style'},
          {'mediaId': '91', 'purpose': 'identity'},
        ],
        ..._selection.config.toJson(),
      },
    },
  },
};

void main() {
  test(
    'content and task outputs accept plain-text and historical payloads',
    () {
      const prompt = '全片15秒，无BGM。\n镜头01：保持角色一致。';
      for (final payload in [
        prompt,
        {'text': prompt},
        {'body': prompt},
        {'description': prompt},
        {'modelPrompt': prompt, 'shots': []},
      ]) {
        final output = <String, Object?>{
          'kind': 'storyboard',
          'payload': payload,
        };
        final block = ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'content',
          'data': output,
        });
        final step = ConversationTaskStep.fromJson({
          'key': 'storyboard',
          'state': 'completed',
          'output': output,
        });
        expect(block.isStoryboard, isTrue);
        expect(block.body, step.content!.body);
        expect(HomeStoryboard.displayText(block.body), prompt);
        expect(block.data['payload'], payload);
      }
    },
  );

  late Dio dio;
  late PreferencesStorage storage;
  ApiSessionRepository repository() => ApiSessionRepository(
    NetworkAgentApi(dio),
    NetworkApi(dio),
    () => storage,
  );
  setUp(() async {
    dio = Dio();
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
  });
  tearDown(() => dio.close(force: true));

  test('unrelated SSE retains scope and presentation metadata', () {
    final message = {
      ...chatMessageJson(),
      'attempt': 3,
      'transient': true,
      'presentation': 'reply',
      'blocks': [
        {
          'type': 'object',
          'kind': 'topic',
          'action': 'generated',
          'scope': {'kind': 'creation', 'id': '40'},
          'data': {
            'ref': {'kind': 'topic', 'id': '50'},
          },
        },
      ],
    };
    final snapshot = ConversationSnapshot.fromJson(
      chatSnapshotJson(seq: 1, messages: [message]),
    );
    final updated = applyConversationEvent(
      snapshot,
      chatEvent(2, 'run.started', {'runId': 'new-run'}),
    );
    final retained = updated.messages.single;
    expect(retained.attempt, 3);
    expect(retained.transient, isTrue);
    expect(retained.presentation, 'reply');
    expect(retained.blocks.single.scopeId, '40');
    expect(retained.blocks.single.referenceId, '50');
  });

  test('snapshot failures allow retry unless explicitly disabled', () {
    for (final state in ['failed', 'interrupted']) {
      expect(
        ConversationRun.fromJson({'id': 'run', 'state': state}).retryable,
        isTrue,
      );
      expect(
        ConversationRun.fromJson({
          'id': 'run',
          'state': state,
          'retryable': false,
        }).retryable,
        isFalse,
      );
    }
    expect(
      ConversationRun.fromJson({'id': 'run', 'state': 'completed'}).retryable,
      isFalse,
    );
  });

  test('later topic batches lock only their own creation', () {
    Map<String, Object?> message(int seq, String scope, String action) => {
      ...chatMessageJson(seq: seq),
      'id': 'message-$seq',
      'blocks': [
        {
          'type': 'object',
          'kind': 'topic',
          'action': action,
          'scope': {'kind': 'creation', 'id': scope},
          'data': {
            'ref': {'kind': 'topic', 'id': '$seq'},
          },
        },
      ],
    };
    final snapshot = ConversationSnapshot.fromJson(
      chatSnapshotJson(
        messages: [
          message(1, '40', 'generated'),
          message(2, '41', 'generated'),
          message(3, '40', 'selected'),
        ],
      ),
    );
    expect(
      snapshot.topicLocked(
        snapshot.messages[0],
        snapshot.messages[0].blocks.single,
      ),
      isTrue,
    );
    expect(
      snapshot.selectedTopicId(
        snapshot.messages[0],
        snapshot.messages[0].blocks.single,
      ),
      '3',
    );
    expect(
      snapshot.topicLocked(
        snapshot.messages[1],
        snapshot.messages[1].blocks.single,
      ),
      isFalse,
    );
  });

  test('task video output is renderable once, including numeric IDs', () {
    final block = ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'task',
      'action': 'home',
      'data': {
        'outputs': [
          {'kind': 'media', 'id': '81'},
        ],
        'steps': [
          {
            'key': 'video',
            'state': 'completed',
            'output': {'kind': 'video', 'mediaId': 81},
          },
        ],
      },
    });
    final task = ConversationTaskView(block, null);
    expect(task.steps.single.content!.mediaIds, ['81']);
    expect(task.steps.single.mediaIds, ['81']);
    expect(task.mediaIds, isEmpty);
  });

  test(
    'home task uses frozen cast and resolves the exact artifact version',
    () {
      final snapshot = ConversationSnapshot.fromJson({
        ...chatSnapshotJson(),
        'sessionCast': [
          {
            'id': 12,
            'title': 'Current name',
            'avatar': 'current.png',
            'profileVersion': {
              'id': 'role-v2',
              'profile': {'title': 'Current name'},
            },
          },
        ],
        'contents': [
          {
            'id': 'latest',
            'ref': {'id': 'script', 'versionId': 'v2'},
            'kind': 'script',
            'body': 'Latest revision',
          },
          {
            'id': 'saved',
            'ref': {'id': 'script', 'versionId': 'v1'},
            'kind': 'script',
            'body': 'Approved script',
          },
        ],
      });
      final block = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'task',
        'action': 'home',
        'data': {
          'input': {
            'cast': [
              {
                'roleId': 12,
                'versionId': 'role-v1',
                'profile': {
                  'title': 'Saved name',
                  'description': 'Saved character',
                },
              },
            ],
          },
          'steps': [
            {
              'key': 'script',
              'state': 'completed',
              'output': {'id': 'script', 'versionId': 'v1', 'kind': 'script'},
            },
          ],
        },
      });
      final task = ConversationTaskView(block, snapshot);
      expect(task.roles.single.title, 'Saved name');
      expect(task.roles.single.referenceId, '12');
      expect(task.roles.single.reference?['versionId'], 'role-v1');
      expect(task.roles.single.data['profile'], {
        'title': 'Saved name',
        'description': 'Saved character',
      });
      expect(task.roles.single.avatar, isNull);
      expect(task.steps.single.content!.body, 'Approved script');
      expect(task.steps.single.content!.reference?['versionId'], 'v1');
    },
  );

  test('home task can use matching saved portrait and legacy cast profile', () {
    final snapshot = ConversationSnapshot.fromJson({
      ...chatSnapshotJson(),
      'sessionCast': [
        {
          'id': 12,
          'title': 'Saved name',
          'avatar': 'saved.png',
          'profileVersion': {
            'id': 'role-v1',
            'profile': {'title': 'Saved name'},
          },
        },
      ],
    });
    ConversationBlock task({bool frozen = true}) => ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'task',
      'action': 'home',
      'data': {
        if (frozen)
          'input': {
            'cast': [
              {
                'roleId': 12,
                'versionId': 'role-v1',
                'profile': {'title': 'Saved name'},
              },
            ],
          },
      },
    });
    for (final frozen in [true, false]) {
      final role = ConversationTaskView(
        task(frozen: frozen),
        snapshot,
      ).roles.single;
      expect(role.title, 'Saved name');
      expect(role.avatar, '${AppConfig.apiBaseUrl}/saved.png');
      expect(role.data['profile'], {'title': 'Saved name'});
    }
  });

  test('proposal exposes backend estimate with quote fallback', () {
    final proposal = ConversationTaskProposal.fromJson({
      'status': 'ready',
      'estimate': {'estimatedPoints': 8},
      'quote': {'maxPoints': 12},
      'plan': {
        'items': [
          {'prompt': 'A fixed prompt'},
        ],
      },
    });
    expect(proposal.estimatedPoints, 8);
    expect(proposal.prompts, ['A fixed prompt']);
    expect(
      ConversationTaskProposal.fromJson({
        'quote': {'maxPoints': 12},
      }).estimatedPoints,
      12,
    );
  });

  test(
    'model reference constraints include unsupported, minimum and maximum',
    () {
      final model = HomeModel.fromJson({
        'id': 'model',
        'available': true,
        'referenceSchema': {
          'image': {'supported': true, 'min': 1, 'max': 2},
        },
      });
      expect(model.acceptsImageReferences(0), isFalse);
      expect(model.acceptsImageReferences(1), isTrue);
      expect(model.acceptsImageReferences(2), isTrue);
      expect(model.acceptsImageReferences(3), isFalse);
      final unsupported = HomeModel.fromJson({
        'id': 'model',
        'referenceSchema': {
          'image': {'supported': false, 'min': 0, 'max': null},
        },
      });
      expect(unsupported.acceptsImageReferences(0), isTrue);
      expect(unsupported.acceptsImageReferences(1), isFalse);
    },
  );

  for (final failure in [
    'timeout',
    'INSUFFICIENT_POINTS',
    'MEDIA_PREFERENCES_CHANGED',
  ]) {
    test(
      'role configuration survives $failure and repository recreation',
      () async {
        final configurations = <Map<String, Object?>>[];
        final authorizations = <Map<String, Object?>>[];
        final paths = <String>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              paths.add(options.path);
              Object? response = <String, Object?>{};
              if (options.path.endsWith('/configuration')) {
                configurations.add(
                  Map<String, Object?>.from(options.data as Map),
                );
                response = {'request': _configuredRequest()};
              } else if (options.path.endsWith('/generation/confirmations')) {
                authorizations.add(
                  Map<String, Object?>.from(options.data as Map),
                );
                if (authorizations.length == 1) {
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: failure == 'timeout'
                          ? DioExceptionType.connectionTimeout
                          : DioExceptionType.badResponse,
                      response: failure == 'timeout'
                          ? null
                          : Response(
                              requestOptions: options,
                              statusCode: 409,
                              data: {'code': failure, 'retryable': false},
                            ),
                    ),
                  );
                  return;
                }
                response = {'data': {}};
              } else if (options.path.endsWith('/media-models')) {
                response = {
                  'data': {'list': []},
                };
              } else if (options.path.endsWith('/session-media-preferences')) {
                response = {
                  'data': {'revision': 3, 'image': _selection.config.toJson()},
                };
              } else {
                expect(options.path.endsWith('/respond'), isTrue);
                expect(
                  (options.data as Map)['generationConfig'],
                  _selection.config.toJson(),
                );
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: response,
                ),
              );
            },
          ),
        );
        await expectLater(
          repository().confirmGeneration('a', chatId, _card(), _selection),
          throwsA(
            failure == 'timeout'
                ? isA<DioException>()
                : isA<AgentApiException>(),
          ),
        );
        final recovery = (await repository().generationOptions(
          'a',
          chatId,
          _card(),
        )).recovery!;
        expect(recovery.referenceMediaId, '91');
        expect(recovery.roleTemplateTitle, 'Line art');
        expect(recovery.roleTemplateMediaId, '90');
        expect(
          recovery.mediaPreferencesRevision,
          failure == 'MEDIA_PREFERENCES_CHANGED' ? 3 : 2,
        );
        await repository().confirmGeneration(
          'a',
          chatId,
          _card(),
          const ConversationGenerationSelection(
            config: HomeConfig(modelId: 'different', params: {}),
            estimatedPoints: 100,
            mediaPreferencesRevision: 99,
          ),
        );
        expect(configurations[0], configurations[1]);
        expect(authorizations[1]['input'], authorizations[0]['input']);
        expect(authorizations[1]['maxEstimatedPoints'], 8);
        expect(
          authorizations[1]['mediaPreferencesRevision'],
          recovery.mediaPreferencesRevision,
        );
        expect(paths.take(2), [
          '/api_agent/v2/sessions/$chatId/confirmations/confirmation/configuration',
          '/api_client/agent/v2/generation/confirmations',
        ]);
        expect(storage.preferences.getKeys(), isEmpty);
      },
    );
  }

  for (final preferredMode in [null, 'text_to_video']) {
    test(
      'generation confirmation retains the prepared mode over $preferredMode',
      () async {
        const preparedMode = 'reference_to_video';
        final plan = {
          'key': 'video',
          'mediaType': 'video',
          'modelId': 'video-model',
          'prompt': 'Animate the character',
          'params': {'duration': 5, 'generationMode': preparedMode},
          'references': [
            {'mediaId': '91', 'purpose': 'reference'},
          ],
        };
        final generation = {'creatorInputId': 'fixed-input', 'item': plan};
        final body = {
          'clientRequestId': 'business-confirmation',
          'input': generation,
        };
        final card = ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'plan',
          'data': {
            'id': 'confirmation',
            'kind': 'generation',
            'status': 'ready',
            'revision': 1,
            'allowedActions': ['confirm', 'cancel'],
            'plan': {
              'items': [plan],
            },
            'request': {
              'method': 'POST',
              'path': '/api_client/agent/v2/generation/confirmations',
              'body': body,
            },
          },
        });
        final selection = ConversationGenerationSelection(
          config: HomeConfig(
            modelId: 'selected-video-model',
            params: {
              'duration': 10,
              if (preferredMode != null) 'generationMode': preferredMode,
            },
          ),
          estimatedPoints: 8,
          mediaPreferencesRevision: 2,
        );
        final expectedConfig = {
          'modelId': 'selected-video-model',
          'params': {'duration': 10, 'generationMode': preparedMode},
        };
        final paths = <String>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              paths.add(options.path);
              final data = options.data as Map;
              if (options.path.endsWith('/generation/confirmations')) {
                expect(data['clientRequestId'], body['clientRequestId']);
                expect(data['maxEstimatedPoints'], 8);
                expect(data['mediaPreferencesRevision'], 2);
                expect(data['input'], {
                  ...generation,
                  'item': {...plan, ...expectedConfig},
                });
              } else {
                expect(options.path.endsWith('/respond'), isTrue);
                expect(data['generationConfig'], expectedConfig);
                expect(data['revision'], 1);
                expect(data['action'], 'confirm');
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.path.endsWith('/respond')
                      ? <String, Object?>{}
                      : {'data': <String, Object?>{}},
                ),
              );
            },
          ),
        );

        await repository().confirmGeneration('a', chatId, card, selection);

        expect(paths, [
          '/api_client/agent/v2/generation/confirmations',
          '/api_agent/v2/sessions/$chatId/confirmations/confirmation/respond',
        ]);
        expect(storage.preferences.getKeys(), isEmpty);
        expect(card.request!['body'], body);
        expect(selection.config.params['generationMode'], preferredMode);
      },
    );
  }

  test('cancel discards persisted uncertain generation inputs', () async {
    var canceling = false;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (canceling) {
            expect(options.path.endsWith('/respond'), isTrue);
            expect((options.data as Map)['action'], 'cancel');
            handler.resolve(
              Response(requestOptions: options, data: <String, Object?>{}),
            );
          } else {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
              ),
            );
          }
        },
      ),
    );
    await expectLater(
      repository().confirmGeneration('a', chatId, _card(), _selection),
      throwsA(isA<DioException>()),
    );
    expect(storage.preferences.getKeys(), isNotEmpty);
    canceling = true;
    await repository().confirm('a', chatId, _card(), 'cancel');
    expect(storage.preferences.getKeys(), isEmpty);
  });

  test(
    'home plan uses generate and cancel despite empty allowedActions',
    () async {
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            if (options.path.endsWith('/generate')) {
              expect(
                (options.data as Map).keys,
                unorderedEquals(['clientRequestId', 'config']),
              );
            } else {
              expect(options.data, isEmpty);
            }
            handler.resolve(
              Response(requestOptions: options, data: <String, Object?>{}),
            );
          },
        ),
      );
      await repository().confirmGeneration(
        'a',
        chatId,
        _card(home: true),
        _selection,
      );
      await repository().confirm('a', chatId, _card(home: true), 'cancel');
      expect(paths, [
        '/api_agent/v2/sessions/$chatId/home-plans/confirmation/generate',
        '/api_agent/v2/sessions/$chatId/home-plans/confirmation/cancel',
      ]);
    },
  );

  test('home and workflow task commands respect separate schemas', () async {
    final commands = <Map<String, Object?>>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          commands.add(Map<String, Object?>.from(options.data as Map));
          handler.resolve(
            Response(requestOptions: options, data: <String, Object?>{}),
          );
        },
      ),
    );
    ConversationBlock task(String action) => ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'task',
      'action': action,
      'data': {
        'id': 'task',
        'state': 'awaiting_confirmation',
        'confirmationPending': true,
        'allowedActions': ['pause'],
      },
    });
    await repository().controlTask('a', task('home'), 'pause');
    await repository().controlTask('a', task('home'), 'confirm-video');
    await repository().controlTask(
      'a',
      task('workflow'),
      'pause',
      capabilities: {
        'revision': 9,
        'allowedActions': ['pause'],
      },
    );
    expect(commands[0].keys, unorderedEquals(['clientRequestId', 'action']));
    expect(commands[1].keys, ['clientRequestId']);
    expect(commands[2].keys, unorderedEquals(['clientRequestId', 'revision']));
    expect(commands[2]['revision'], 9);
  });

  test(
    'topic retry keeps its request ID and uses the session endpoint',
    () async {
      var reads = 0;
      final commands = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET') {
              reads++;
              expect(options.path, '/api_client/agent/v2/creations/40');
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'data': {
                      'creation': {'sessionId': chatId, 'revision': 7},
                      'editable': true,
                    },
                  },
                ),
              );
            } else {
              expect(options.method, 'PUT');
              expect(options.path, '/api_agent/v2/sessions/$chatId/topic');
              commands.add(Map<String, Object?>.from(options.data as Map));
              if (commands.length == 1) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionTimeout,
                  ),
                );
              } else {
                handler.resolve(
                  Response(requestOptions: options, data: {'snapshot': {}}),
                );
              }
            }
          },
        ),
      );
      final topic = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'topic',
        'action': 'generated',
        'scope': {'kind': 'creation', 'id': '40'},
        'data': {
          'ref': {'kind': 'topic', 'id': '50'},
        },
      });
      await expectLater(
        repository().topicAction('a', chatId, topic),
        throwsA(isA<DioException>()),
      );
      await repository().topicAction('a', chatId, topic);
      expect(reads, 0);
      expect(commands[0], commands[1]);
      expect(commands[1].keys, unorderedEquals(['clientRequestId', 'topicId']));
      expect(commands[1]['topicId'], '50');
    },
  );
}
