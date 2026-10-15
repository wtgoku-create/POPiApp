import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/payments/data/apple_payment_store.dart';
import 'package:popi_ai_app/features/payments/data/apple_payment_repository.dart';
import 'package:popi_ai_app/features/payments/data/apple_purchase_service.dart';
import 'package:popi_ai_app/features/payments/data/pending_apple_purchase_storage.dart';
import 'package:popi_ai_app/features/profile/data/purchase_catalog_repository.dart';
import 'package:popi_ai_app/features/profile/presentation/membership_page.dart';
import 'package:popi_ai_app/features/profile/presentation/points_details_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/purchase_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';

class _Store extends ApplePaymentStore {
  final queries = <Set<String>>[];
  final missing = <String>{};
  bool isAvailable = true;

  @override
  Future<bool> available() async => isAvailable;

  @override
  Future<List<AppleStoreProduct>> products(Set<String> ids) async {
    queries.add(ids);
    return [
      for (final id in ids)
        if (!missing.contains(id)) AppleStoreProduct(id, id, 'HK\$38.00'),
    ];
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, Object?> _mapping({
  int id = 301,
  String kind = 'subscription',
  bool enabled = true,
}) => {
  'id': id,
  'product_id': 'com.popi.ios.$id',
  'kind': kind,
  'plan_id': kind == 'points' ? 0 : 202,
  'package_id': kind == 'points' ? 203 : 0,
  'amount_fen': 3800,
  'grant_points': 2000,
  'enabled': enabled,
  'sales_channel': 'ios',
  'title': 'Apple product $id',
  'description':
      'Included courses\n\n<title>Video models</title>\n\n<mark>Seedance 2.0</mark> model',
  'member_level': '2',
  'plan_category': 'yearly',
  'duration_unit': 'year',
  'duration_value': 1,
  'points_amount': 1900,
  'bonus_points': 100,
  'points_grant_mode': 'once',
  'validity_period': 'year',
};

Map<String, Object?> _maxMapping() => {
  ..._mapping(id: 6),
  'product_id': 'popistudio.max.36500.monthly',
  'plan_id': 39,
  'title': 'Max 作品研修',
  'amount_fen': 129900,
  'original_price_amount': 2069,
  'original_amount_fen': 206900,
  'custom_info': {
    'point_amount': '每100积分≈￥3.56元',
    'discount_info': '限时 6.3折',
    'goal_title': '专属内容｜独家连麦诊断帐号内容',
    'goal_description': '导师连麦诊断账号与作品',
    'buttonText': '立即购买',
    'feature_title': 'Max-IP诊断',
  },
  'member_level': '4',
  'plan_category': 'monthly',
  'duration_unit': 'month',
  'duration_value': 1,
  'grant_points': 25550,
  'points_amount': 25550,
  'bonus_points': 0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late PurchaseCatalogRepository repository;
  final requests = <RequestOptions>[];
  List<Map<String, Object?>> mappings = [];

  setUp(() {
    store = _Store();
    requests.clear();
    mappings = [
      _mapping(),
      _mapping(id: 302, kind: 'points'),
      _mapping(id: 303, kind: 'upgrade'),
      _mapping(id: 304, enabled: false),
    ];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'status': '0000', 'data': mappings},
              ),
            );
          },
        ),
      );
    repository = PurchaseCatalogRepository(
      NetworkApi(dio),
      useAppleCatalog: true,
    );
  });

  test(
    'Apple membership uses server mapping IDs and prices without StoreKit',
    () async {
      final plans = await repository.plans();
      expect(plans.map((item) => item.id), [202]);
      expect(plans.map((item) => item.appleProductVersionId), [301]);
      expect(plans.first.localizedPrice, isNull);
      expect(plans.first.price, 3800);
      expect(plans.first.description, _mapping()['description']);
      expect(plans.first.level, 2);
      expect(plans.first.months, 12);
      expect(plans.first.planCategory, 'yearly');
      expect(plans.first.coins + plans.first.bonusPointsAmount, 2000);
      expect(store.queries, isEmpty);
      expect(requests.single.path, '/api_client/trade/payment/apple/products');
      expect(requests.single.queryParameters, isEmpty);
    },
  );

  test(
    'Apple membership preserves original price and display metadata',
    () async {
      mappings = [_maxMapping()];
      final plan = (await repository.plans()).single;
      expect(plan.originalPriceAmount, 2069);
      expect(plan.customInfo?.pointAmount, '每100积分≈￥3.56元');
      expect(plan.customInfo?.discountInfo, '限时 6.3折');
      expect(plan.customInfo?.featureTitle, 'Max-IP诊断');
      expect(plan.customInfo?.buttonText, '立即购买');
      expect(plan.customInfo?.goalTitle, '专属内容｜独家连麦诊断帐号内容');
      expect(plan.customInfo?.goalDescription, '导师连麦诊断账号与作品');
      expect(plan.price, 129900);
      expect(plan.coins, 25550);
      expect(plan.bonusPointsAmount, 0);
      expect(plan.planCategory, 'monthly');
      expect(plan.months, 1);
      expect(plan.appleProductId, 'popistudio.max.36500.monthly');
      expect(plan.appleProductVersionId, 6);
    },
  );

  test(
    'Apple catalog displays regular prices and excludes upgrade mappings',
    () async {
      mappings = [
        {..._mapping(), 'regular_amount_fen': 6800},
        {..._mapping(id: 302, kind: 'points'), 'regular_amount_fen': 1800},
        _mapping(id: 303, kind: 'upgrade'),
      ];
      final plan = (await repository.plans()).single;
      final package = (await repository.pointPackages()).single;
      expect(plan.appleProductVersionId, 301);
      expect(plan.price, 6800);
      expect(package.priceAmount, 18);
      expect(requests.every((r) => r.queryParameters.isEmpty), isTrue);
    },
  );

  test('Apple membership accepts absent or invalid display metadata', () async {
    for (final customInfo in [null, 'unavailable', <Object?>[]]) {
      mappings = [
        {..._mapping(), 'custom_info': customInfo},
      ];
      final plan = (await repository.plans()).single;
      expect(plan.originalPriceAmount, 0);
      expect(plan.customInfo, isNull);
      expect(plan.price, 3800);
    }
  });

  test(
    'Apple points preserve server mapping, price and package validity',
    () async {
      final package = (await repository.pointPackages()).single;
      expect(package.id, 203);
      expect(package.appleProductVersionId, 302);
      expect(package.appleProductId, 'com.popi.ios.302');
      expect(package.localizedPrice, isNull);
      expect(package.priceAmount, 38);
      expect(package.name, 'Apple product 302');
      expect(package.totalPoints, 2000);
      expect(package.validityPeriod, 'year');
      expect(store.queries, isEmpty);
      expect(requests.single.path, '/api_client/trade/payment/apple/products');
    },
  );

  test(
    'empty and missing Apple products never fall back to standard products',
    () async {
      mappings = [];
      expect(await repository.plans(), isEmpty);
      expect(store.queries, isEmpty);
      mappings = [_mapping()];
      store.missing.add('com.popi.ios.301');
      expect(await repository.plans(), hasLength(1));
      expect(
        requests.every((item) => item.path.endsWith('/apple/products')),
        isTrue,
      );
    },
  );

  test('StoreKit unavailable does not block either Apple catalog', () async {
    store.isAvailable = false;
    expect(await repository.plans(), hasLength(1));
    expect(await repository.pointPackages(), hasLength(1));
    expect(store.queries, isEmpty);
    expect(requests, hasLength(2));
  });

  test('Android catalogs use standard list envelopes and units', () async {
    requests.clear();
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'status': '0000',
                  'data': request.path.endsWith('/plan/list')
                      ? {
                          'list': [
                            {'id': 102, 'price': 6800, 'coins': 6800},
                          ],
                        }
                      : [
                          {
                            'id': 201,
                            'price_amount': 18,
                            'points_amount': 1500,
                            'bonus_points': 100,
                            'enabled': true,
                          },
                        ],
                },
              ),
            );
          },
        ),
      );
    final standard = PurchaseCatalogRepository(NetworkApi(dio));
    expect((await standard.plans()).single.price, 6800);
    final package = (await standard.pointPackages()).single;
    expect(package.id, 201);
    expect(package.priceAmount, 18);
    expect(package.totalPoints, 1600);
    expect(package.appleProductVersionId, isNull);
    expect(requests.map((item) => item.path), [
      '/api_client/products/plan/list',
      '/api_client/users/pointPackage/list',
    ]);
  });

  Future<void> pumpApplePage(
    WidgetTester tester,
    Widget page, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = ApplePurchaseService(
      repository: ApplePaymentRepository(repository.api),
      storage: PendingApplePurchaseStorage(
        PreferencesStorage(preferences),
        'user',
      ),
      store: store,
      supported: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          dioProvider.overrideWithValue(repository.api.dio),
          applePurchaseServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'iOS membership displays server annual price without StoreKit',
    (tester) async {
      await pumpApplePage(tester, const MembershipPage());
      expect(requests.single.path, '/api_client/trade/payment/apple/products');
      expect(find.text('38'), findsOneWidget);
      expect(find.text('每年'), findsOneWidget);
      expect(find.text('积分/月'), findsNothing);
      expect(find.text('¥'), findsOneWidget);
      expect(find.text('确认支付'), findsOneWidget);
      expect(
        find.textContaining('Included courses', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('Seedance 2.0', findRichText: true),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'iOS membership renders Apple display metadata at ${width.toInt()}px',
      (tester) async {
        mappings = [_maxMapping()];
        await pumpApplePage(tester, const MembershipPage(), width: width);
        expect(find.text('1299'), findsOneWidget);
        final originalPrice = find.text('¥2069');
        expect(originalPrice, findsOneWidget);
        expect(
          tester.widget<Text>(originalPrice).style?.decoration,
          TextDecoration.lineThrough,
        );
        expect(find.text('每100积分≈￥3.56元'), findsOneWidget);
        expect(find.text('限时 6.3折'), findsOneWidget);
        expect(find.text('Max-IP诊断'), findsOneWidget);
        expect(find.text('立即购买'), findsOneWidget);
        expect(find.text('确认支付'), findsNothing);
        expect(find.text('25550'), findsOneWidget);
        expect(find.text('每月'), findsOneWidget);
        expect(find.text('每年'), findsNothing);
        expect(store.queries, isEmpty);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'iOS points entry displays server prices even when StoreKit is unavailable',
    (tester) async {
      store.isAvailable = false;
      await pumpApplePage(
        tester,
        const PointsDetailsPage(
          refreshOnOpen: false,
          loadPointsLogOnOpen: false,
        ),
      );
      await tester.tap(find.byKey(const Key('points-recharge-entry')));
      await tester.pumpAndSettle();
      expect(requests.single.path, '/api_client/trade/payment/apple/products');
      expect(find.text('¥38'), findsOneWidget);
      expect(store.queries, isEmpty);
      expect(find.byKey(const Key('points-package-2000')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
