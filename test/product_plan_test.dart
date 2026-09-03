import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/profile/data/product_plan_repository.dart';

void main() {
  test('requests type 1 plans and parses data.list', () async {
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
                'status': '0000',
                'message': 'ok',
                'data': {
                  'list': [
                    {
                      'id': 12,
                      'type': 1,
                      'image': '',
                      'title': 'Max 作品研修',
                      'description': '<mark>包含Pro 全部课程</mark>\n\n'
                          '<title>视频模型</title>',
                      'details': null,
                      'level': 4,
                      'coins': 36500,
                      'months': 1,
                      'days': 0,
                      'power': 0,
                      'videoLength': 0,
                      'audioLength': 0,
                      'original_price_amount': 2069,
                      'custom_info': {
                        'buttonText': '立即购买',
                        'discount_info': '限时 6.3折',
                        'feature_title': 'Max-IP诊断',
                        'goal_description': '导师连麦诊断账号与作品',
                        'goal_title': '专属内容｜独家连麦诊断帐号内容',
                        'new_user': true,
                        'point_amount': '每100积分≈￥3.56元',
                        'apple_product_id':
                            'com.popiai.app.subscription.max.monthly',
                      },
                      'planCategory': 'monthly',
                      'pointsGrantMode': 'once',
                      'bonusPointsAmount': 0,
                      'price': 129900,
                      'oldPrice': 0,
                      'recommended': false,
                      'sortNum': 6,
                      'status': 1,
                      'createTime': '0001-01-01T00:00:00Z',
                      'updateTime': '0001-01-01T00:00:00Z',
                      'deleted': false,
                      'deleteTime': null,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final plans = await ProductPlanRepository(NetworkApi(dio)).fetchAll();

    expect(request.path, '/api_client/products/plan/list');
    expect(request.queryParameters, {'type': 1});
    expect(plans, hasLength(1));

    final plan = plans.single;
    expect(plan.id, 12);
    expect(plan.title, 'Max 作品研修');
    expect(plan.description, contains('<title>视频模型</title>'));
    expect(plan.details, isNull);
    expect(plan.level, 4);
    expect(plan.coins, 36500);
    expect(plan.months, 1);
    expect(plan.originalPriceAmount, 2069);
    expect(plan.customInfo?.buttonText, '立即购买');
    expect(plan.customInfo?.discountInfo, '限时 6.3折');
    expect(plan.customInfo?.featureTitle, 'Max-IP诊断');
    expect(plan.customInfo?.goalDescription, '导师连麦诊断账号与作品');
    expect(plan.customInfo?.goalTitle, '专属内容｜独家连麦诊断帐号内容');
    expect(plan.customInfo?.newUser, isTrue);
    expect(plan.customInfo?.pointAmount, '每100积分≈￥3.56元');
    expect(
      plan.appleProductId,
      'com.popiai.app.subscription.max.monthly',
    );
    expect(plan.planCategory, 'monthly');
    expect(plan.pointsGrantMode, 'once');
    expect(plan.price, 129900);
    expect(plan.recommended, isFalse);
    expect(plan.sortNum, 6);
    expect(plan.status, 1);
    expect(plan.createTime, DateTime.utc(1));
    expect(plan.deleted, isFalse);
    expect(plan.deleteTime, isNull);
  });
}
