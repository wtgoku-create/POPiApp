import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/dio_client.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';

class _Tokens implements TokenStorage {
  int reads = 0;

  @override
  Future<String?> readAccessToken() async {
    reads++;
    return 'account-test-token';
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
  test('normal business transport retains account authentication', () async {
    final tokens = _Tokens();
    final adapter = _CaptureAdapter();
    final dio = DioClient(secureStorage: tokens).dio
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);

    await dio.get<Object?>('/probe');

    expect(tokens.reads, 1);
    expect(
      adapter.request!.headers['Authorization'],
      'Bearer account-test-token',
    );
  });

  test(
    'local Harness transport never reads or forwards the account token',
    () async {
      final tokens = _Tokens();
      final adapter = _CaptureAdapter();
      final dio = DioClient(secureStorage: tokens, useAuthentication: false).dio
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);

      await dio.get<Object?>('/probe');

      expect(tokens.reads, 0);
      expect(adapter.request!.headers.containsKey('Authorization'), isFalse);
    },
  );
}
