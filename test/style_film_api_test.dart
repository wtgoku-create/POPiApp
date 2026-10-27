import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/features/demo/domain/demo_style_film_models.dart';

void main() {
  late Dio dio;
  late NetworkAgentApi api;
  late List<RequestOptions> requests;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://agent.example'));
    api = NetworkAgentApi(dio);
    requests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(requestOptions: request, data: <String, dynamic>{}),
          );
        },
      ),
    );
  });
  tearDown(() => dio.close(force: true));

  test(
    'catalog uses only its exact read route and supported query vocabulary',
    () async {
      await api.styleFilmCatalog(
        q: '  ink  ',
        category: 'painting',
        page: 2,
        pageSize: 12,
      );
      expect(requests.single.path, '/api_agent/v2/style-films/catalog');
      expect(requests.single.method, 'GET');
      expect(requests.single.queryParameters, {
        'q': 'ink',
        'category': 'painting',
        'page': 2,
        'pageSize': 12,
      });
      expect(requests.single.data, isNull);
    },
  );

  test(
    'normal messages omit invocation and film messages send bounded structured arguments',
    () async {
      await api.sendSessionMessage(
        's1',
        clientRequestId: 'normal',
        text: 'Hello',
      );
      expect(requests.single.data, {
        'clientRequestId': 'normal',
        'text': 'Hello',
      });
      const invocation = DemoStyleFilmInvocation(
        selection: DemoStyleFilmSelection(
          styleId: 'impasto',
          styleNameZh: '油画',
        ),
      );
      await api.sendSessionMessage(
        's1',
        clientRequestId: 'film',
        text: 'A new story',
        mediaIds: ['image-1'],
        contextRoleIds: ['cat'],
        skillInvocation: invocation.toJson(),
      );
      expect(requests.last.path, '/api_agent/v2/sessions/s1/messages');
      expect(requests.last.data, {
        'clientRequestId': 'film',
        'text': 'A new story',
        'mediaIds': ['image-1'],
        'contextRoleIds': ['cat'],
        'skillInvocation': {
          'skillId': 'lemo-opuscar',
          'arguments': {
            'styleId': 'impasto',
            'durationSeconds': 15,
            'aspectRatio': '9:16',
            'storyboardReview': true,
            'soundtrack': 'none',
          },
        },
      });
    },
  );

  test(
    'review sends revision and idempotency on the independent durable route',
    () async {
      await api.reviewStyleFilm(
        's1',
        'job-1',
        clientRequestId: 'review-1',
        expectedRevision: 3,
        action: 'revise',
        notes: '  New plan  ',
      );
      expect(
        requests.single.path,
        '/api_agent/v2/sessions/s1/style-films/job-1/review',
      );
      expect(requests.single.method, 'POST');
      expect(requests.single.data, {
        'clientRequestId': 'review-1',
        'expectedRevision': 3,
        'action': 'revise',
        'notes': 'New plan',
      });
      expect(
        () => api.reviewStyleFilm(
          's1',
          'job-1',
          clientRequestId: 'bad',
          expectedRevision: 3,
          action: 'cancel',
        ),
        throwsArgumentError,
      );
      expect(
        () => api.reviewStyleFilm(
          's1',
          'job-1',
          clientRequestId: 'bad',
          expectedRevision: 0,
          action: 'approve',
        ),
        throwsArgumentError,
      );
      expect(
        () => api.reviewStyleFilm(
          's1',
          'job-1',
          clientRequestId: 'bad',
          expectedRevision: 3,
          action: 'revise',
          notes: 'x' * 2001,
        ),
        throwsArgumentError,
      );
      expect(requests, hasLength(1));
    },
  );

  test(
    'style poster resolution rejects external, credentials, path traversal, query and fragments',
    () {
      expect(
        api.resolveStyleFilmPosterUrl(
          '/api_agent/v2/style-films/styles/ink-wash/poster',
        ),
        'https://agent.example/api_agent/v2/style-films/styles/ink-wash/poster',
      );
      for (final value in [
        'https://evil.example/api_agent/v2/style-films/styles/ink-wash/poster',
        'https://user:secret@agent.example/api_agent/v2/style-films/styles/ink-wash/poster',
        '/api_agent/v2/style-films/styles/../poster',
        '/api_agent/v2/style-films/styles/ink-wash/poster?path=private',
        '/api_agent/v2/style-films/styles/ink-wash/poster#fragment',
        '/api_agent/v2/assets/style-1/content',
      ]) {
        expect(
          () => api.resolveStyleFilmPosterUrl(value),
          throwsFormatException,
        );
      }
    },
  );
}
