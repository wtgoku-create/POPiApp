import 'dart:async';

import 'package:dio/dio.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/features/role_guide/data/home_creation_repository.dart';

/// A stateful HTTP fixture: writes alter the next server snapshot.
class HomeCreationFixture {
  HomeCreationFixture() {
    _install(business, false);
    _install(agent, true);
  }
  final business = Dio(BaseOptions(baseUrl: 'http://business.test'));
  final agent = Dio(BaseOptions(baseUrl: 'http://agent.test'));
  final requests = <RequestOptions>[];
  String accountId = '101';
  int revision = 1;
  int creationNumber = 0;
  List<int> cast = [1];
  List<Map<String, Object?>> topics = [];
  Map<String, Object?>? selected;
  Map<String, Object?>? config;
  Map<String, Object?>? task;
  int recommendationCount = 0;
  bool failEntryOnce = false;
  bool failTopicsOnce = false;
  bool failGenerateOnce = false;
  bool failMediaOnce = false;
  bool failRoleSaveOnce = false;
  bool failPreferenceSaveOnce = false;
  final modelCatalogs = <String, List<Map<String, Object?>>>{};
  int mediaPreferenceRevision = 1;
  Map<String, Object?> videoPreference = {
    'modelId': '501',
    'params': {'duration': 15, 'ratio': '9:16'},
  };
  Map<String, Object?>? imagePreference;
  final creationProfiles = <int, Map<String, Object?>>{};
  Completer<void>? waitForEntry;
  Completer<void>? waitForTopics;
  HomeCreationRepository get repository =>
      HomeCreationRepository(NetworkApi(business), NetworkAgentApi(agent));

  Map<String, Object?> role(int id) => {
    'id': id,
    'title': 'Character $id',
    'description': 'Profile $id',
    'avatar': 'assets/images/role_guide_avatar_$id.png',
    'canRead': true,
    'canUseVideo': true,
    'profileComplete': true,
    'profileVersion': {
      'id': '${id}1',
      'version': 1,
      'profile': {'title': 'Character $id'},
    },
  };
  Map<String, Object?> snapshot() => {
    'creation': {
      'id': '${(accountId == '101' ? 301 : 302) + creationNumber}',
      'accountId': accountId,
      'sessionId': '11111111-1111-4111-8111-111111111111',
      'revision': revision,
    },
    'currentRevision': {
      'id': 'revision-$revision',
      'brief': 'Brief',
      'outputMode': 'video',
      'accountProfileVersionId': null,
      'inputContentVersionIds': <String>[],
      'cast': [
        for (final id in cast)
          {
            ...role(id),
            if (creationProfiles[id] case final profile?) ...{
              'title': profile['title'],
              'description': profile['description'],
              'profile': profile,
              'creationRoleVersionId': 'local-$id-$revision',
              'profileVersion': {
                ...Map<String, Object?>.from(role(id)['profileVersion'] as Map),
                'profile': profile,
              },
            },
          },
      ],
      'specs': {if (config != null) 'homeConfig': config},
    },
    'editable': task == null,
    'topics': topics,
    'customTopics': <Object>[],
    'selectedTopic': selected,
    'task': task,
  };
  Map<String, Object?> taskValue(
    String state, {
    int version = 1,
    String lock = 'held',
  }) => {
    'id': '22222222-2222-4222-8222-222222222222',
    'revision': version,
    'state': state,
    'lock': lock,
    'allowedActions': state == 'paused'
        ? ['resume', 'cancel']
        : state == 'awaiting_confirmation'
        ? ['cancel']
        : state == 'running' || state == 'queued'
        ? ['pause', 'cancel']
        : <String>[],
    'confirmationPending': state == 'awaiting_confirmation',
    if (state == 'awaiting_confirmation')
      'confirmationReason': 'storyboard_review',
    'steps': [
      for (final key in ['persona', 'script', 'storyboard', 'video', 'review'])
        {
          'key': key,
          'state': state == 'completed' ? 'completed' : 'pending',
          if (state == 'completed')
            'output': {'id': '$key-id', 'title': key, 'body': '$key output'},
        },
    ],
  };
  void _install(Dio dio, bool isAgent) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          requests.add(request);
          try {
            final result = await _dispatch(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: isAgent ? result : {'status': '0000', 'data': result},
              ),
            );
          } catch (error) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.receiveTimeout,
                error: error,
              ),
            );
          }
        },
      ),
    );
  }

  Future<Map<String, Object?>> _dispatch(RequestOptions request) async {
    final path = request.path;
    final body = request.data is Map
        ? Map<String, Object?>.from(request.data as Map)
        : <String, Object?>{};
    if (path.endsWith('/home/enter')) {
      if (waitForEntry != null) await waitForEntry!.future;
      if (failEntryOnce) {
        failEntryOnce = false;
        throw StateError('Entry response lost');
      }
      if (body['accountId'] != null) accountId = body['accountId'] as String;
      if (body['roleIds'] is List) cast = (body['roleIds'] as List).cast<int>();
      if (body['newCreation'] == true) {
        task = null;
        topics = [];
        selected = null;
        config = null;
        creationNumber++;
        revision = 1;
      }
      return snapshot();
    }
    if (path.endsWith('/topics')) {
      if (waitForTopics != null) await waitForTopics!.future;
      recommendationCount++;
      topics = [
        {
          'id': 'topic-$recommendationCount',
          'title': body['mode'] == 'custom'
              ? 'Custom story: ${body['text']}'
              : 'Server story $recommendationCount',
          'summary': 'A story returned by the server',
        },
      ];
      if (failTopicsOnce) {
        failTopicsOnce = false;
        throw StateError('Topic response lost');
      }
      return {'batch': {}, 'items': topics, 'snapshot': snapshot()};
    }
    if (path.endsWith('/topic')) {
      selected = topics.firstWhere((topic) => topic['id'] == body['topicId']);
      revision++;
      return {'snapshot': snapshot()};
    }
    if (path.endsWith('/role-versions')) {
      if (failRoleSaveOnce) {
        failRoleSaveOnce = false;
        throw StateError('Role save unavailable');
      }
      creationProfiles[body['roleId'] as int] = Map<String, Object?>.from(
        body['profile'] as Map,
      );
      selected = null;
      topics = [];
      revision++;
      return snapshot();
    }
    if (path.endsWith('/cast')) {
      cast = (body['roleIds'] as List).cast<int>();
      selected = null;
      topics = [];
      revision++;
      return {
        'cast': [for (final id in cast) role(id)],
        'messageId': null,
        'runId': null,
      };
    }
    if (path.endsWith('/roles')) {
      return {
        'list': [role(1), role(2)],
        'pageInfo': {'page': 1, 'pageCount': 1},
      };
    }
    if (path.contains('/roles/')) return role(int.parse(path.split('/').last));
    if (path.endsWith('/accounts')) {
      final page = request.queryParameters['page'] as int;
      return {
        'list': [
          if (page == 1)
            {'id': '101', 'title': 'First project', 'status': 'active'}
          else
            {'id': '202', 'title': 'Second project', 'status': 'active'},
        ],
        'pageInfo': {'page': page, 'pageSize': 10, 'pageCount': 2, 'total': 2},
      };
    }
    if (path.endsWith('/session-media-preferences')) {
      if (request.method == 'PUT') {
        if (failPreferenceSaveOnce) {
          failPreferenceSaveOnce = false;
          throw StateError('Preference save unavailable');
        }
        final saved = Map<String, Object?>.from(body['config'] as Map);
        if (body['mediaType'] == 'video') {
          videoPreference = saved;
        } else {
          imagePreference = saved;
        }
        mediaPreferenceRevision++;
      }
      return {
        'revision': mediaPreferenceRevision,
        'video': videoPreference,
        'image': imagePreference,
      };
    }
    if (path.endsWith('/media-models')) {
      final mediaType = request.queryParameters['mediaType'] as String;
      if (modelCatalogs.containsKey(mediaType)) {
        return {'list': modelCatalogs[mediaType]};
      }
      if (mediaType == 'image') return {'list': <Map<String, Object?>>[]};
      return {
        'list': [
          {
            'id': '501',
            'name': 'Server video model',
            'available': true,
            'isDefault': true,
            'mediaType': 'video',
            'parameters': [
              {
                'name': 'duration',
                'label': 'Duration',
                'type': 'integer',
                'required': true,
                'default': 5,
                'options': [5, 15, 30],
              },
              {
                'name': 'ratio',
                'label': 'Ratio',
                'type': 'string',
                'required': true,
                'default': '9:16',
                'options': ['9:16', '16:9'],
              },
            ],
          },
          {
            'id': '502',
            'name': 'Unavailable',
            'available': false,
            'mediaType': 'video',
            'parameters': [],
          },
        ],
      };
    }
    if (path.endsWith('/estimate-points')) return {'estimatedPoints': 42};
    if (path.endsWith('/home/generate')) {
      config = Map<String, Object?>.from(body['config'] as Map);
      task = taskValue('queued');
      if (failGenerateOnce) {
        failGenerateOnce = false;
        throw StateError('Generation response lost');
      }
      return {'task': task};
    }
    if (path.endsWith('/control') || path.endsWith('/confirm-video')) {
      task = taskValue(
        switch (body['action']) {
          'pause' => 'paused',
          'cancel' => 'canceled',
          _ => 'running',
        },
        version: (task!['revision'] as int) + 1,
        lock: body['action'] == 'cancel' ? 'released' : 'held',
      );
      return {'task': task};
    }
    if (path.contains('/home-tasks/')) return {'task': task};
    if (path.contains('/media/')) {
      if (failMediaOnce) {
        failMediaOnce = false;
        throw StateError('Media unavailable');
      }
      return {'url': '/generated/video.mp4'};
    }
    throw StateError('Unexpected request $path');
  }
}
