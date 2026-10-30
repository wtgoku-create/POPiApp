import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/business_agent_transport.dart';

void main() {
  test(
    'web uses browser Cookie and never attaches the legacy Bearer token',
    () async {
      final adapter = _Adapter();
      final dio = createBusinessAgentDio(
        baseUrl: 'https://app.example',
        origin: 'https://app.example',
        token: 'legacy-token',
        isWeb: true,
        isCurrent: () => true,
        onUnauthorized: () async {},
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      await dio.get<Object?>(
        '/api_agent/v2/assets',
        options: Options(
          headers: {'Authorization': 'Bearer legacy', 'Cookie': 'forged'},
        ),
      );
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        false,
      );
      expect(adapter.requests.single.headers.containsKey('Cookie'), false);
    },
  );
  test(
    'pins the login token and never sends it outside the Agent origin',
    () async {
      final adapter = _Adapter();
      final dio = createBusinessAgentDio(
        baseUrl: 'https://agent.example',
        origin: 'https://agent.example',
        token: 'user-a',
        isWeb: false,
        isCurrent: () => true,
        onUnauthorized: () async {},
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      await dio.get<Object?>(
        '/api_agent/v2/sessions',
        options: Options(headers: {'authorization': 'forged', 'Cookie': 'old'}),
      );
      expect(adapter.requests.single.headers['Authorization'], 'Bearer user-a');
      expect(adapter.requests.single.headers.containsKey('Cookie'), false);
      expect(adapter.requests.single.followRedirects, false);
      await expectLater(
        dio.get<Object?>('https://other.example/api_agent/v2/sessions'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests.length, 1);
    },
  );

  for (final status in [200, 401]) {
    test(
      'late $status responses cannot update or invalidate the next login',
      () async {
        var active = true;
        var invalidations = 0;
        final adapter = _Adapter(delayed: true, status: status);
        final dio = createBusinessAgentDio(
          baseUrl: 'https://agent.example',
          origin: 'https://agent.example',
          token: 'user-a',
          isWeb: false,
          isCurrent: () => active,
          onUnauthorized: () async {
            invalidations++;
          },
        )..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final pending = dio.get<Object?>('/api_agent/v2/sessions');
        final expectation = expectLater(pending, throwsA(isA<DioException>()));
        await adapter.started.future;
        active = false;
        adapter.release.complete();
        await expectation;
        expect(invalidations, 0);
        await expectLater(
          dio.get<Object?>('/api_agent/v2/sessions'),
          throwsA(isA<DioException>()),
        );
        expect(adapter.requests.length, 1);
      },
    );
  }

  test('current 401 clears login but a resource 403 does not', () async {
    var invalidations = 0;
    for (final status in [401, 403]) {
      final dio = createBusinessAgentDio(
        baseUrl: 'https://agent.example',
        origin: 'https://agent.example',
        token: 'user-a',
        isWeb: false,
        isCurrent: () => true,
        onUnauthorized: () async {
          invalidations++;
        },
      )..httpClientAdapter = _Adapter(status: status);
      await expectLater(
        dio.get<Object?>('/api_agent/v2/sessions'),
        throwsA(isA<DioException>()),
      );
      dio.close(force: true);
    }
    expect(invalidations, 1);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.delayed = false, this.status = 200});
  final bool delayed;
  final int status;
  final started = Completer<void>();
  final release = Completer<void>();
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!started.isCompleted) started.complete();
    if (delayed) await release.future;
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
