import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/demo/domain/harness_access_session.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';

class _Tokens implements TokenStorage {
  int reads = 0;

  @override
  Future<String?> readAccessToken() async {
    reads++;
    return 'account-token-must-not-leave-the-app';
  }

  @override
  Future<void> writeAccessToken(String token) async {}

  @override
  Future<void> deleteAccessToken() async {}
}

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const agentBaseUrl = 'http://127.0.0.1:3084';
  const appOrigin = 'http://127.0.0.1:7357';

  test(
    'native local Harness sends its allowed Origin without account auth',
    () async {
      final tokens = _Tokens();
      final adapter = _CaptureAdapter();
      final dio = createAgentDio(
        secureStorage: tokens,
        baseUrl: agentBaseUrl,
        origin: appOrigin,
        localHarnessEnabled: true,
        isWeb: false,
      )..httpClientAdapter = adapter;
      addTearDown(dio.close);

      await dio.get<Object?>('/api_agent/v2/sessions');

      expect(tokens.reads, 0);
      expect(adapter.request!.headers['Origin'], appOrigin);
      expect(adapter.request!.headers.containsKey('Authorization'), isFalse);
    },
  );

  test('Web local Harness leaves Origin ownership to the browser', () async {
    final tokens = _Tokens();
    final adapter = _CaptureAdapter();
    final dio = createAgentDio(
      secureStorage: tokens,
      baseUrl: agentBaseUrl,
      origin: appOrigin,
      localHarnessEnabled: true,
      isWeb: true,
    )..httpClientAdapter = adapter;
    addTearDown(dio.close);

    await dio.get<Object?>('/api_agent/v2/sessions');

    expect(tokens.reads, 0);
    expect(adapter.request!.headers.containsKey('Origin'), isFalse);
    expect(adapter.request!.headers.containsKey('Authorization'), isFalse);
  });

  test('local Harness refuses non-loopback Agent hosts', () {
    expect(
      () => createAgentDio(
        secureStorage: _Tokens(),
        baseUrl: 'https://agent.example',
        origin: appOrigin,
        localHarnessEnabled: true,
        isWeb: false,
      ),
      throwsStateError,
    );
  });

  test(
    'authenticated native remote Harness sends scoped access without account auth',
    () async {
      final tokens = _Tokens();
      final adapter = _CaptureAdapter();
      final session = HarnessAccessSession(
        cookieValue: 'test-session',
        origin: 'https://harness.example',
        expiresAt: DateTime.utc(2099),
        cacheNamespace: '123e4567-e89b-42d3-a456-426614174000',
      );
      final dio = createAgentDio(
        secureStorage: tokens,
        baseUrl: 'https://harness.example',
        origin: 'https://harness.example',
        remoteHarnessEnabled: true,
        isWeb: false,
        harnessAccessSession: session,
      )..httpClientAdapter = adapter;
      addTearDown(dio.close);

      await dio.get<Object?>('/api_agent/v2/sessions');

      expect(tokens.reads, 0);
      expect(_header(adapter.request!, 'Origin'), 'https://harness.example');
      expect(_header(adapter.request!, 'Cookie'), session.cookieHeader);
      expect(_header(adapter.request!, 'Authorization'), isNull);
    },
  );

  test('Web remote Harness leaves Origin ownership to the browser', () async {
    final tokens = _Tokens();
    final adapter = _CaptureAdapter();
    final dio = createAgentDio(
      secureStorage: tokens,
      baseUrl: 'https://harness.example',
      origin: 'https://harness.example',
      remoteHarnessEnabled: true,
      isWeb: true,
    )..httpClientAdapter = adapter;
    addTearDown(dio.close);

    await dio.get<Object?>('/api_agent/v2/sessions');

    expect(tokens.reads, 0);
    expect(adapter.request!.headers.containsKey('Origin'), isFalse);
    expect(adapter.request!.headers.containsKey('Authorization'), isFalse);
  });

  test('remote Harness refuses HTTP and credential-bearing URLs', () {
    for (final baseUrl in [
      'http://harness.example',
      'https://user:secret@harness.example',
      'https://harness.example?channel=test',
      'https://harness.example#fragment',
    ]) {
      expect(
        () => createAgentDio(
          secureStorage: _Tokens(),
          baseUrl: baseUrl,
          origin: 'https://harness.example',
          remoteHarnessEnabled: true,
        ),
        throwsStateError,
        reason: baseUrl,
      );
    }
  });

  test('remote Harness requires a clean same-origin HTTPS Origin', () {
    for (final origin in [
      '',
      'http://harness.example',
      'https://other.example',
      'https://harness.example/path',
      'https://user@harness.example',
    ]) {
      expect(
        () => createAgentDio(
          secureStorage: _Tokens(),
          baseUrl: 'https://harness.example',
          origin: origin,
          remoteHarnessEnabled: true,
        ),
        throwsStateError,
        reason: origin,
      );
    }
  });

  test('local and remote Harness transports are mutually exclusive', () {
    expect(
      () => createAgentDio(
        secureStorage: _Tokens(),
        baseUrl: agentBaseUrl,
        origin: appOrigin,
        localHarnessEnabled: true,
        remoteHarnessEnabled: true,
      ),
      throwsStateError,
    );
  });
}

Object? _header(RequestOptions request, String name) {
  final normalized = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == normalized) return entry.value;
  }
  return null;
}
