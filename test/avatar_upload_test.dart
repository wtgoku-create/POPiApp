import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';

void main() {
  test(
    'uploads avatar multipart and accepts both website response formats',
    () async {
      for (final payload in [
        {
          'status': '0000',
          'data': {'url': 'https://example.com/avatar.png'},
        },
        {'url': 'https://example.com/avatar.png'},
      ]) {
        final dio = Dio();
        late RequestOptions request;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(Response(requestOptions: options, data: payload));
            },
          ),
        );
        final url = await NetworkApi(
          dio,
        ).uploadAvatar(bytes: [1, 2, 3], filename: 'avatar.png');
        expect(url, 'https://example.com/avatar.png');
        expect(request.path, '/api_client/media/upload');
        expect(request.method, 'POST');
        final form = request.data as FormData;
        expect(Map.fromEntries(form.fields), {'directory': 'avatar'});
        expect(form.files.single.key, 'file');
        expect(form.files.single.value.filename, 'avatar.png');
      }
    },
  );

  test('rejects missing upload URL and failed responses', () async {
    for (final payload in [
      {'status': '0000', 'data': <String, dynamic>{}},
      {'status': '4001', 'url': 'https://example.com/avatar.png'},
    ]) {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(Response(requestOptions: options, data: payload));
          },
        ),
      );
      await expectLater(
        NetworkApi(dio).uploadAvatar(bytes: [1], filename: 'avatar.png'),
        throwsA(isA<ApiException>()),
      );
    }
  });
}
