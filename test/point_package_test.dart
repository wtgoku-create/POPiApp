import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/profile/data/point_package_repository.dart';

void main() {
  test('requests, filters, sorts, and parses point packages', () async {
    late RequestOptions request;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': [
                  {
                    'id': 2,
                    'name': 'disabled',
                    'currency': 'CNY',
                    'price_amount': 10,
                    'points_amount': 100,
                    'bonus_points': 0,
                    'enabled': false,
                    'sort_order': 0,
                    'created_at': 1775117426,
                    'updated_at': 1779432180,
                  },
                  {
                    'id': 1,
                    'name': '30包',
                    'currency': 'CNY',
                    'price_amount': 30,
                    'points_amount': 600,
                    'bonus_points': 0,
                    'enabled': true,
                    'sort_order': 1,
                    'created_at': 1775117426,
                    'updated_at': 1779432180,
                  },
                  {
                    'id': 3,
                    'name': 'bonus',
                    'currency': 'CNY',
                    'price_amount': '50.50',
                    'points_amount': 1000,
                    'bonus_points': 100,
                    'enabled': true,
                    'sort_order': 2,
                    'created_at': 0,
                    'updated_at': 0,
                  },
                ],
                'message': 'ok',
                'status': '0000',
              },
            ),
          );
        },
      ),
    );

    final packages = await PointPackageRepository(
      NetworkApi(dio),
    ).fetchAll();

    expect(request.path, '/api_client/users/pointPackage/list');
    expect(packages.map((item) => item.id), [1, 3]);

    final package = packages.first;
    expect(package.name, '30包');
    expect(package.currency, 'CNY');
    expect(package.priceAmount, 30);
    expect(package.pointsAmount, 600);
    expect(package.bonusPoints, 0);
    expect(package.totalPoints, 600);
    expect(package.enabled, isTrue);
    expect(package.sortOrder, 1);
    expect(
      package.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1775117426000, isUtc: true),
    );
    expect(
      package.updatedAt,
      DateTime.fromMillisecondsSinceEpoch(1779432180000, isUtc: true),
    );

    expect(packages.last.priceAmount, 50.5);
    expect(packages.last.totalPoints, 1100);
    expect(packages.last.createdAt, isNull);
  });
}
