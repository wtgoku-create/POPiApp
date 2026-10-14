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
  'member_level': '2',
  'plan_category': 'yearly',
  'duration_unit': 'year',
  'duration_value': 1,
  'points_amount': 1900,
  'bonus_points': 100,
  'points_grant_mode': 'once',
  'validity_period': 'year',
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
      appleStore: store,
      environment: 'Sandbox',
    );
  });

  test(
    'Apple membership uses mapping IDs and StoreKit prices without quoting',
    () async {
      final plans = await repository.plans();
      expect(plans.map((item) => item.id), [202, 202]);
      expect(plans.map((item) => item.appleProductVersionId), [301, 303]);
      expect(plans.first.localizedPrice, 'HK\$38.00');
      expect(plans.first.price, 3800);
      expect(plans.first.level, 2);
      expect(plans.first.months, 12);
      expect(plans.first.planCategory, 'yearly');
      expect(plans.first.coins + plans.first.bonusPointsAmount, 2000);
      expect(store.queries, [
        {'com.popi.ios.301', 'com.popi.ios.303'},
      ]);
      expect(requests.single.path, '/api_client/trade/payment/apple/products');
      expect(requests.single.queryParameters, {'environment': 'Sandbox'});
    },
  );

  test(
    'Apple points preserve mapping, localized price and package validity',
    () async {
      final package = (await repository.pointPackages()).single;
      expect(package.id, 203);
      expect(package.appleProductVersionId, 302);
      expect(package.appleProductId, 'com.popi.ios.302');
      expect(package.localizedPrice, 'HK\$38.00');
      expect(package.totalPoints, 2000);
      expect(package.validityPeriod, 'year');
      expect(store.queries.single, {'com.popi.ios.302'});
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
      await expectLater(repository.plans(), throwsStateError);
      expect(
        requests.every((item) => item.path.endsWith('/apple/products')),
        isTrue,
      );
    },
  );

  test(
    'StoreKit failure remains a catalog error without standard fallback',
    () async {
      store.isAvailable = false;
      await expectLater(repository.plans(), throwsStateError);
      expect(requests, hasLength(1));
    },
  );

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

  Future<void> pumpApplePage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
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
      environment: 'Sandbox',
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
    'iOS membership loads Apple catalog and displays localized annual price',
    (tester) async {
      await pumpApplePage(tester, const MembershipPage());
      expect(requests.single.path, '/api_client/trade/payment/apple/products');
      expect(find.text('HK\$38.00'), findsOneWidget);
      expect(find.text('每年'), findsOneWidget);
      expect(find.text('积分/月'), findsNothing);
      expect(find.text('¥'), findsNothing);
      expect(find.text('确认支付'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS points entry loads only Apple packages with localized prices',
    (tester) async {
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
      expect(find.text('HK\$38.00'), findsOneWidget);
      expect(find.byKey(const Key('points-package-2000')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
