import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Deterministic activity HTTP responses for repository and navigation tests.
class ActivityFixture {
  ActivityFixture() {
    dio.interceptors.add(InterceptorsWrapper(onRequest: _request));
  }

  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  final requests = <RequestOptions>[];
  List<Map<String, Object?>> activities = [
    {
      'id': 1,
      'name': '新手活动礼包',
      'desp': '仅限新用户参加',
      'status': 1,
      'tags': '[{"label":"NEW","bgColor":"#F2EDFF","textColor":"#6F47F5"}]',
    },
    {
      'id': 2,
      'name': '创作者权益卡',
      'type': 'book_card',
      'status': 1,
      'memberLevels': [1, 2, 3],
    },
  ];
  bool listFails = false;
  bool membersFail = false;
  bool refreshFails = false;
  String activationStatus = '0000';
  String? qrUrl;
  Completer<void>? pendingActivation;
  Completer<void>? pendingRefresh;

  Future<void> _request(
    RequestOptions request,
    RequestInterceptorHandler handler,
  ) async {
    requests.add(request);
    try {
      String status = '0000';
      final Map<String, Object?> data;
      switch (request.path) {
        case '/api_client/users/activity/list':
          if (listFails) throw StateError('List unavailable');
          data = {'list': activities};
        case '/api_client/users/member/list':
          if (membersFail) throw StateError('Members unavailable');
          data = {
            'list': [
              {'memberLevel': 1, 'memberName': '创作尝鲜卡'},
              {'memberLevel': 2, 'memberName': '创作进阶卡'},
              {'memberLevel': 3, 'memberName': '创作全能卡'},
            ],
          };
        case '/api_client/users/activeCode/use':
          await pendingActivation?.future;
          status = activationStatus;
          data = {if (qrUrl != null) 'url': qrUrl};
        case '/api_client/users/user/info':
          await pendingRefresh?.future;
          if (refreshFails) throw StateError('Refresh unavailable');
          data = {
            'user': {
              'id': '1',
              'name': 'User',
              'memberLevel': 1,
              'allCoins': 500,
            },
          };
        default:
          throw StateError('Unexpected request: ${request.path}');
      }
      handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: request,
          statusCode: 200,
          data:
              jsonDecode(
                    jsonEncode({
                      'status': status,
                      'message': '兑换码无效',
                      'data': data,
                    }),
                  )
                  as Map<String, dynamic>,
        ),
      );
    } catch (error) {
      handler.reject(DioException(requestOptions: request, error: error));
    }
  }
}
