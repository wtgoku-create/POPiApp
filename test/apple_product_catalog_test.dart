import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/app_config.dart';
import 'package:popi_ai_app/features/payments/domain/apple_product_catalog.dart';

void main() {
  for (final brand in AppBrand.values) {
    final config = AppConfig(brand);
    test('${brand.name}: validates all 11 products and types', () {
      expect(appleCreditSuffixes.length, 6);
      expect(appleMembershipSuffixes.length, 5);
      for (final suffix in appleCreditSuffixes) {
        final id = '${brand.name}.$suffix';
        expect(resolveAppleProductId(id, config: config, consumable: true), id);
        expect(appleProductType(id, config: config), appleConsumableType);
        expect(resolveAppleProductId(id, config: config), isEmpty);
      }
      for (final suffix in appleMembershipSuffixes) {
        final id = '${brand.name}.$suffix';
        expect(resolveAppleProductId(' $id ', config: config), id);
        expect(appleProductType(id, config: config), appleMembershipType);
        expect(resolveAppleProductId(id, config: config, consumable: true),
            isEmpty);
      }
    });
    test('${brand.name}: rejects missing, legacy and other app products', () {
      final other = brand == AppBrand.popi ? 'popistudio' : 'popi';
      for (final id in [
        '',
        '  ',
        'popi.membership.starter.30d',
        '$other.max.36500.monthly',
        '${brand.name}.unknown'
      ]) {
        expect(resolveAppleProductId(id, config: config), isEmpty);
      }
    });
  }
  test('flavors select identifiers and independent WeChat apps', () {
    expect(AppConfig.fromFlavor('popi').bundleId, 'com.popiai.app');
    expect(AppConfig.fromFlavor('popistudio').bundleId, 'com.popistudio.app');
    expect(AppConfig.fromFlavor('popistudio').wechatEnabled, isTrue);
    expect(
        AppConfig.fromFlavor('popistudio').wechatAppId, 'wx0d9c23195606fc80');
    expect(AppConfig.fromFlavor('popi').wechatAppId, 'wxf99ad5d5c7b4fe37');
    expect(AppConfig.fromFlavor('popistudio').wechatUniversalLink,
        'https://app.popi.art/WeChat/');
    expect(() => AppConfig.fromFlavor('typo'), throwsStateError);
  });
}
