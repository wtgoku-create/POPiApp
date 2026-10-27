import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/demo/domain/harness_access_session.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';

void main() {
  final now = DateTime.now().toUtc();
  HarnessAccessSession session(String cookie, String namespace) =>
      HarnessAccessSession(
        cookieValue: cookie,
        origin: 'https://harness.example',
        expiresAt: now.add(const Duration(hours: 1)),
        cacheNamespace: namespace,
      );

  test(
    'remote transport keeps cookies on its exact Agent API origin',
    () async {
      final adapter = _ImmediateAdapter(200);
      final current = session(
        'cookie-one',
        '123e4567-e89b-42d3-a456-426614174000',
      );
      final dio = createAgentDio(
        secureStorage: const _Tokens(),
        baseUrl: 'https://harness.example',
        origin: 'https://harness.example',
        remoteHarnessEnabled: true,
        isWeb: false,
        readHarnessAccessSession: () => current,
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      await dio.get<Object?>('/api_agent/v2/sessions');
      expect(adapter.requests.single.headers['Cookie'], current.cookieHeader);
      expect(
        adapter.requests.single.headers['Origin'],
        'https://harness.example',
      );

      await dio.get<Object?>(
        'https://attacker.example/api_agent/v2/sessions',
        options: Options(
          headers: {
            'cookie': 'caller-supplied-secret',
            'origin': 'https://harness.example',
          },
        ),
      );
      final crossOrigin = adapter.requests.last;
      expect(
        crossOrigin.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('cookie')),
      );
      expect(
        crossOrigin.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('origin')),
      );
      expect(crossOrigin.followRedirects, isFalse);
    },
  );

  test(
    'a late 401 from an old cookie cannot invalidate a new session',
    () async {
      final oldSession = session(
        'old-cookie',
        '123e4567-e89b-42d3-a456-426614174000',
      );
      final newSession = session(
        'new-cookie',
        '123e4567-e89b-42d3-a456-426614174001',
      );
      var current = oldSession;
      var invalidations = 0;
      final adapter = _DelayedUnauthorizedAdapter();
      final dio = createAgentDio(
        secureStorage: const _Tokens(),
        baseUrl: 'https://harness.example',
        origin: 'https://harness.example',
        remoteHarnessEnabled: true,
        isWeb: false,
        readHarnessAccessSession: () => current,
        onHarnessUnauthorized: () {
          invalidations++;
        },
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      final oldRequest = dio.get<Object?>('/api_agent/v2/sessions');
      await adapter.started.future;
      current = newSession;
      adapter.release.complete();
      await expectLater(oldRequest, throwsA(isA<DioException>()));
      expect(invalidations, 0);

      await expectLater(
        dio.get<Object?>('/api_agent/v2/sessions'),
        throwsA(isA<DioException>()),
      );
      expect(invalidations, 1);
    },
  );

  test('an expired session is invalidated before the request leaves', () async {
    HarnessAccessSession? current = HarnessAccessSession(
      cookieValue: 'expired-cookie',
      origin: 'https://harness.example',
      expiresAt: now.subtract(const Duration(seconds: 1)),
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174000',
    );
    var invalidations = 0;
    final adapter = _ImmediateAdapter(200);
    final dio = createAgentDio(
      secureStorage: const _Tokens(),
      baseUrl: 'https://harness.example',
      origin: 'https://harness.example',
      remoteHarnessEnabled: true,
      isWeb: false,
      readHarnessAccessSession: () => current,
      onHarnessUnauthorized: () {
        invalidations++;
        current = null;
      },
    )..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    await expectLater(
      dio.get<Object?>('/api_agent/v2/sessions'),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );

    expect(invalidations, 1);
    expect(current, isNull);
    expect(adapter.requests, isEmpty);
  });

  test('login transport uses a non-following form POST', () async {
    final adapter = _ImmediateAdapter(
      303,
      headers: {
        'location': ['/'],
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://harness.example'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    await NetworkAgentApi(
      dio,
    ).signInHarness(username: 'tester', password: 'one-time-password');

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/login');
    expect(request.contentType, Headers.formUrlEncodedContentType);
    expect(request.followRedirects, isFalse);
    expect(request.maxRedirects, 0);
    expect(request.data, {
      'username': 'tester',
      'password': 'one-time-password',
    });
  });
}

class _ImmediateAdapter implements HttpClientAdapter {
  _ImmediateAdapter(this.statusCode, {this.headers = const {}});

  final int statusCode;
  final Map<String, List<String>> headers;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedUnauthorizedAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  var release = Completer<void>();
  var calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (calls == 1) {
      started.complete();
      await release.future;
    }
    return ResponseBody.fromString('{}', 401);
  }

  @override
  void close({bool force = false}) {}
}

class _Tokens implements TokenStorage {
  const _Tokens();

  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<String?> readAccessToken() async =>
      throw StateError('Harness must not read account auth');

  @override
  Future<void> writeAccessToken(String token) async {}
}
