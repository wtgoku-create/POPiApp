import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/features/payments/domain/apple_product_catalog.dart';

void main() {
  test('configures the sandbox product as a non-renewing subscription', () {
    expect(appleTestProductType, 'nonRenewingSubscription');
  });

  test('uses the shared sandbox product when no product is configured', () {
    expect(resolveAppleProductId(''), 'popi.membership.starter.30d');
    expect(resolveAppleProductId('   '), 'popi.membership.starter.30d');
  });

  test('forces the shared sandbox product during integration testing', () {
    expect(
      resolveAppleProductId(' popi.membership.max.30d '),
      'popi.membership.starter.30d',
    );
  });
}
