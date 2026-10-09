import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';

void main() {
  test('deletes a work with its original id and cancellation token', () async {
    final dio = Dio();
    late RequestOptions request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: {'status': '0000'}),
          );
        },
      ),
    );
    final token = CancelToken();
    await NetworkApi(dio).deleteLibraryWork('work / 1', cancelToken: token);
    expect(request.method, 'GET');
    expect(request.path, '/api_client/anime/asset/delete');
    expect(request.queryParameters, {'id': 'work / 1'});
    expect(request.cancelToken, same(token));
  });

  test('preserves a work deletion business failure', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'status': '1001', 'message': 'Cannot delete work'},
            ),
          );
        },
      ),
    );
    await expectLater(
      NetworkApi(dio).deleteLibraryWork('1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Cannot delete work',
        ),
      ),
    );
  });

  for (final deleting in [false, true]) {
    test(
      'cancelled work ${deleting ? 'deletion' : 'list'} never starts',
      () async {
        final dio = Dio();
        var requests = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests++;
              handler.resolve(Response(requestOptions: options, data: {}));
            },
          ),
        );
        final api = NetworkApi(dio);
        final token = CancelToken()..cancel();
        await expectLater(
          deleting
              ? api.deleteLibraryWork('1', cancelToken: token)
              : api.listLibraryWorks(
                  type: 0,
                  page: 1,
                  pageSize: 20,
                  cancelToken: token,
                ),
          throwsA(
            isA<DioException>().having(
              (error) => error.type,
              'type',
              DioExceptionType.cancel,
            ),
          ),
        );
        expect(requests, 0);
      },
    );
  }
}
