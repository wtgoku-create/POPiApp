import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/profile/data/user_points_log_repository.dart';

void main() {
  test('requests and parses a page of user points logs', () async {
    late RequestOptions request;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'pageInfo': {
                    'page': '1',
                    'pageSize': '20',
                    'pageCount': 516,
                    'total': 10311,
                  },
                  'list': [
                    {
                      'id': '157845',
                      'userId': 0,
                      'userCode': '',
                      'userName': '',
                      'points': '-1',
                      'changeType': 2,
                      'sourceType': 'post_refund',
                      'sourceId': '20260902073829189579696TAsPWvBP',
                      'content': 'deepseek-v4-flash',
                      'beforePoints': 5837,
                      'afterPoints': 5836,
                      'status': 1,
                      'createTime': '2026-09-02T15:38:29+08:00',
                    },
                  ],
                },
                'message': 'ok',
                'status': '0000',
              },
            ),
          );
        },
      ),
    );

    final result = await UserPointsLogRepository(NetworkApi(dio)).fetchPage(
      page: 1,
      pageSize: 20,
    );

    expect(request.path, '/api_client/users/userPointsLog/list');
    expect(request.queryParameters, {'page': 1, 'pageSize': 20});
    expect(result.page, 1);
    expect(result.pageCount, 516);
    expect(result.total, 10311);
    expect(result.hasMore, isTrue);
    expect(result.items, hasLength(1));
    expect(result.items.single.id, 157845);
    expect(result.items.single.points, -1);
    expect(result.items.single.content, 'deepseek-v4-flash');
    expect(result.items.single.beforePoints, 5837);
    expect(result.items.single.afterPoints, 5836);
    expect(
      result.items.single.createTime,
      DateTime.parse('2026-09-02T15:38:29+08:00'),
    );
  });
}
