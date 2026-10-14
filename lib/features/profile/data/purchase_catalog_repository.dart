import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/network_api.dart';
import '../../../shared/type/payment_type.dart';
import '../../payments/data/apple_payment_repository.dart';
import '../../payments/data/apple_payment_store.dart';
import '../../payments/domain/apple_payment.dart';
import '../domain/point_package.dart';
import '../domain/product_plan.dart';
import 'point_package_repository.dart';
import 'product_plan_repository.dart';

/// Apple catalogs come exclusively from eligible mappings and StoreKit prices.
class PurchaseCatalogRepository {
  const PurchaseCatalogRepository(
    this.api, {
    this.appleStore,
    this.environment = AppConfig.applePaymentEnvironment,
  });

  final NetworkApi api;
  final ApplePaymentStore? appleStore;
  final String environment;

  Future<List<(AppleProductMapping, AppleStoreProduct)>> _appleProducts(
    PaymentProductKind kind,
  ) async {
    final mappings = (await ApplePaymentRepository(
      api,
    ).products(environment)).where((item) => item.kind == kind).toList();
    if (kDebugMode) {
      debugPrint(
        'Apple catalog: environment=$environment, kind=${kind.name}, '
        'eligible=${mappings.length}',
      );
    }
    if (mappings.isEmpty) return const [];
    final store = appleStore!;
    if (!await store.available()) throw StateError('StoreKit unavailable');
    final products = {
      for (final product in await store.products(
        mappings.map((item) => item.productId).toSet(),
      ))
        product.id: product,
    };
    if (kDebugMode) {
      debugPrint(
        'Apple catalog: StoreKit matched=${products.length}, '
        'requested=${mappings.length}',
      );
    }
    if (!mappings.any((mapping) => products.containsKey(mapping.productId))) {
      throw StateError('StoreKit returned no matching Apple products');
    }
    return [
      for (final mapping in mappings)
        if (products[mapping.productId] case final product?) (mapping, product),
    ];
  }

  Future<List<ProductPlan>> plans() async {
    if (appleStore == null) return ProductPlanRepository(api).fetchAll();
    return [
      for (final (mapping, product) in await _appleProducts(
        PaymentProductKind.subscription,
      ))
        ProductPlan(
          id: mapping.businessId,
          type: 1,
          image: '',
          title: mapping.title.isEmpty ? product.title : mapping.title,
          description: '',
          details: null,
          level: mapping.memberLevel,
          coins: mapping.pointsAmount,
          months: switch (mapping.durationUnit) {
            'year' => mapping.durationValue * 12,
            'month' => mapping.durationValue,
            _ => 0,
          },
          days: mapping.durationUnit == 'day' ? mapping.durationValue : 0,
          power: 0,
          videoLength: 0,
          audioLength: 0,
          originalPriceAmount: 0,
          customInfo: null,
          planCategory: mapping.planCategory,
          pointsGrantMode: mapping.pointsGrantMode,
          bonusPointsAmount: mapping.bonusPoints,
          price: mapping.amountFen,
          oldPrice: 0,
          recommended: false,
          sortNum: 0,
          status: 1,
          createTime: null,
          updateTime: null,
          deleted: false,
          deleteTime: null,
          appleProductId: mapping.productId,
          appleProductVersionId: mapping.id,
          localizedPrice: product.price,
        ),
    ];
  }

  Future<List<PointPackage>> pointPackages() async {
    if (appleStore == null) return PointPackageRepository(api).fetchAll();
    return [
      for (final (mapping, product) in await _appleProducts(
        PaymentProductKind.points,
      ))
        PointPackage(
          id: mapping.businessId,
          name: mapping.title.isEmpty ? product.title : mapping.title,
          currency: '',
          priceAmount: mapping.amountFen / 100,
          pointsAmount: mapping.pointsAmount,
          bonusPoints: mapping.bonusPoints,
          enabled: true,
          sortOrder: 0,
          createdAt: null,
          updatedAt: null,
          appleProductId: mapping.productId,
          appleProductVersionId: mapping.id,
          localizedPrice: product.price,
          validityPeriod: mapping.validityPeriod,
        ),
    ];
  }
}
