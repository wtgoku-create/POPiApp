import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/session/data/session_artifact_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/domain/session_artifact.dart';

import 'conversation_events_test.dart' show chatMessageJson, chatSnapshotJson;

void main() {
  late Dio dio;
  setUp(() => dio = Dio());
  tearDown(() => dio.close(force: true));

  test(
    'real media outputs merge snapshot contents and timeline without duplicates',
    () {
      final image = <String, Object?>{
        'id': 'image',
        'kind': 'image',
        'title': 'Saved image',
        'mediaIds': ['picture'],
      };
      final snapshot = ConversationSnapshot.fromJson({
        ...chatSnapshotJson(
          messages: [
            {
              ...chatMessageJson(),
              'blocks': [
                {'type': 'object', 'kind': 'content', 'data': image},
                {
                  'type': 'object',
                  'kind': 'content',
                  'data': {
                    'id': 'video',
                    'kind': 'video',
                    'title': 'Saved video',
                    'mediaIds': ['movie'],
                  },
                },
              ],
            },
          ],
        ),
        'contents': [image],
      });
      final items = SessionArtifact.mediaFromSnapshot(snapshot);
      expect(items.map((item) => item.mediaId), ['picture', 'movie']);
      expect(items.map((item) => item.type), [
        SessionArtifactType.image,
        SessionArtifactType.video,
      ]);
      expect(SessionArtifact.mediaFromSnapshot(null), isEmpty);
    },
  );

  test(
    'reads all text pages independently and deduplicates draft IDs',
    () async {
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            final page = request.queryParameters['page'] as int;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'status': '0000',
                  'data': {
                    'list': [
                      {
                        'id': 'shared',
                        'title': 'Version $page',
                        'kind': 'script',
                        'content': '## Body $page',
                      },
                      if (page == 2)
                        {
                          'id': 'second',
                          'kind': 'storyboard',
                          'content': 'Final storyboard',
                          'durationSeconds': 12,
                        },
                    ],
                    'pageInfo': {'pageCount': 2},
                  },
                },
              ),
            );
          },
        ),
      );
      final items = await ApiSessionArtifactRepository(
        NetworkApi(dio),
      ).list('a/b');
      expect(requests, hasLength(2));
      expect(
        requests.first.path,
        '/api_client/agent/v2/sessions/a%2Fb/text-artifacts',
      );
      expect(requests.map((r) => r.queryParameters['page']), [1, 2]);
      expect(items.map((item) => item.id), ['shared', 'second']);
      expect(items.first.title, 'Version 2');
      expect(items.first.summary, '## Body 2');
      expect(items.first.durationSeconds, isNull);
      expect(items.last.textKind, 'storyboard');
      expect(items.last.durationSeconds, 12);
    },
  );

  test(
    'empty sessions do not request data and empty pages stop pagination',
    () async {
      var calls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls++;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'status': '0000',
                  'data': {
                    'list': [],
                    'pageInfo': {'pageCount': 10},
                  },
                },
              ),
            );
          },
        ),
      );
      final repository = ApiSessionArtifactRepository(NetworkApi(dio));
      expect(await repository.list(null), isEmpty);
      expect(await repository.list(''), isEmpty);
      expect(calls, 0);
      expect(await repository.list('session'), isEmpty);
      expect(calls, 1);
    },
  );

  test(
    'failed pages propagate errors without returning incomplete outputs',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'status': '5000', 'message': 'Unavailable'},
              ),
            );
          },
        ),
      );
      await expectLater(
        ApiSessionArtifactRepository(NetworkApi(dio)).list('session'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('cancellation prevents requesting subsequent pages', () async {
    final token = CancelToken();
    var calls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          calls++;
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'status': '0000',
                'data': {
                  'list': [
                    {'id': 'first', 'content': 'First'},
                  ],
                  'pageInfo': {'pageCount': 2},
                },
              },
            ),
          );
          token.cancel();
        },
      ),
    );
    await expectLater(
      ApiSessionArtifactRepository(
        NetworkApi(dio),
        cancelToken: token,
      ).list('session'),
      throwsA(isA<DioException>()),
    );
    expect(calls, 1);
  });
}
