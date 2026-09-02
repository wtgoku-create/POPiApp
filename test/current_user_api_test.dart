import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';

void main() {
  test('loads and parses the current user from the user info endpoint',
      () async {
    late String requestedPath;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedPath = options.path;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'user': {
                    'id': 10006,
                    'code': 'txy',
                    'name': '唐夕阳',
                    'avatar':
                        'https://statictest.popi.art/media/avatar/2026/0416/3734.png',
                    'gender': 1,
                    'birthday': '',
                    'phone': '15671420981',
                    'email': '',
                    'wechat': '',
                    'signature': '1112424',
                    'country': '',
                    'province': '',
                    'city': '',
                    'isMember': true,
                    'memberLevel': 0,
                    'memberName': '活动会员',
                    'memberLabel': 'lv0',
                    'memberCoins': 10,
                    'otherCoins': 73,
                    'pointPackageCoins': 0,
                    'allCoins': 133,
                    'isUsedCoinsRecently': false,
                    'memberEndTime': '2026-09-04T17:21:41+08:00',
                    'power': 0,
                    'powerConsumed': 0,
                    'powerRecharged': 0,
                    'followingNum': 1,
                    'fansNum': 2,
                    'likeNum': 5,
                    'postNum': 9,
                    'taskNum': 0,
                    'characterDesignGuide': false,
                    'status': 1,
                    'createTime': '2025-10-23T17:03:00.336115+08:00',
                    'updateTime': '2026-09-01T15:05:41.670951+08:00',
                  },
                },
                'message': 'ok',
                'status': '0000',
              },
            ),
          );
        },
      ),
    );

    final user = await DefaultAuthApi(NetworkApi(dio)).currentUser();

    expect(requestedPath, '/api_client/users/user/info');
    expect(user.id, '10006');
    expect(user.code, 'txy');
    expect(user.name, '唐夕阳');
    expect(user.isMember, isTrue);
    expect(user.memberName, '活动会员');
    expect(user.memberLabel, 'lv0');
    expect(user.memberCoins, 10);
    expect(user.otherCoins, 73);
    expect(user.allCoins, 133);
    expect(user.followingNum, 1);
    expect(user.fansNum, 2);
    expect(user.likeNum, 5);
    expect(user.postNum, 9);
    expect(user.memberEndTime, DateTime.parse('2026-09-04T17:21:41+08:00'));
  });
}
