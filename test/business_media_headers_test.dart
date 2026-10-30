import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/shared/providers/business_agent_provider.dart';

void main() {
  test('private business images carry owner authorization on web and native', () {
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3085'));
    addTearDown(dio.close);
    final session = BusinessAgentSession(
      userId: '101',
      token: 'owner-token',
      dio: dio,
      cacheNamespace: 'owner-cache',
      invalidate: () async {},
    );
    for (final path in ['content', 'poster', 'thumbnail']) {
      final headers = session.mediaHeaders(
        'http://127.0.0.1:3085/api_agent/v2/assets/test-id/$path',
      );
      expect(headers['Authorization'], 'Bearer owner-token');
      expect(headers.containsKey('Origin'), !kIsWeb);
      expect(headers.containsKey('Cookie'), false);
    }
    expect(
      session.mediaHeaders(
        '/api_agent/v2/assets/test-id/content',
      )['Authorization'],
      'Bearer owner-token',
    );
    for (final url in [
      'https://cdn.example/image.png',
      'https://cos.example/media/video.mp4?ci-process=snapshot&time=0&format=jpg&width=640',
      'http://127.0.0.1:8080/api_agent/v2/assets/test-id/content',
      'http://127.0.0.1:3085/public/image.png',
      'http://user@127.0.0.1:3085/api_agent/v2/assets/test-id/content',
    ]) {
      expect(session.mediaHeaders(url), isEmpty);
    }
  });
}
