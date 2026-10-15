import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
// The generated codec is needed to mock the native boundary, keeping plugin validation real.
// ignore: implementation_imports
import 'package:in_app_purchase_storekit/src/sk2_pigeon.g.dart' as pigeon;
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:popi_ai_app/features/payments/data/apple_payment_store.dart';
import 'package:popi_ai_app/shared/type/payment_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const productId = 'com.popi.points.2000';
  const accountToken = '22222222-2222-4222-8222-222222222222';
  const channelPrefix =
      'dev.flutter.pigeon.in_app_purchase_storekit.InAppPurchase2API';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <BasicMessageChannel<Object?>>[];

  void mock(String method, Future<Object?> Function(Object?) handler) {
    final channel = BasicMessageChannel<Object?>(
      '$channelPrefix.$method',
      pigeon.InAppPurchase2API.pigeonChannelCodec,
    );
    channels.add(channel);
    messenger.setMockDecodedMessageHandler<Object?>(channel, handler);
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    InAppPurchaseStoreKitPlatform.registerPlatform();
  });

  tearDown(() {
    for (final channel in channels) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    }
    channels.clear();
    debugDefaultTargetPlatformOverride = null;
  });

  for (final consumable in [true, false]) {
    test(
      'StoreKit 2 launches consumable=$consumable and finishes only explicitly',
      () async {
        mock('products', (message) async {
          expect((message as List).single, [productId]);
          return [
            [
              SK2Product(
                id: productId,
                displayName: '2000 Points',
                displayPrice: r'HK$38.00',
                description: 'Points',
                price: 38,
                type: consumable
                    ? SK2ProductType.consumable
                    : SK2ProductType.autoRenewable,
                priceLocale: SK2PriceLocale(
                  currencyCode: 'HKD',
                  currencySymbol: r'HK$',
                ),
              ).convertToPigeon(),
            ],
          ];
        });
        var launches = 0;
        mock('purchase', (message) async {
          launches++;
          final arguments = message as List;
          expect(arguments.first, productId);
          final options =
              arguments[1] as pigeon.SK2ProductPurchaseOptionsMessage;
          expect(options.appAccountToken, accountToken);
          expect(options.quantity, 1);
          return [pigeon.SK2ProductPurchaseResultMessage.success];
        });
        final finished = <Object?>[];
        mock('finish', (message) async {
          finished.addAll(message as List);
          return [null];
        });

        final store = NativeApplePaymentStore();
        final product = await store.product(productId);
        expect(product, isNotNull);
        expect(
          await store.buy(product!, accountToken, consumable: consumable),
          AppleStorePurchaseResult.purchased,
        );
        expect(launches, 1);
        expect(finished, isEmpty);
        await store.finish(
          const AppleStoreTransaction(
            id: '10',
            productId: productId,
            status: PurchaseStatus.purchased,
          ),
        );
        expect(finished, [10]);
      },
    );
  }

  for (final result in {
    pigeon.SK2ProductPurchaseResultMessage.userCancelled:
        AppleStorePurchaseResult.canceled,
    pigeon.SK2ProductPurchaseResultMessage.pending:
        AppleStorePurchaseResult.pending,
    pigeon.SK2ProductPurchaseResultMessage.unverified:
        AppleStorePurchaseResult.unverified,
  }.entries) {
    test(
      'preserves native ${result.key.name} without a stream callback',
      () async {
        mock('purchase', (_) async => [result.key]);
        expect(
          await NativeApplePaymentStore().buy(
            const AppleStoreProduct(productId, 'Points', 'HK\$38'),
            accountToken,
            consumable: true,
          ),
          result.value,
        );
      },
    );
  }

  test(
    'a new store instance cannot launch while the previous call waits',
    () async {
      final response = Completer<Object?>();
      mock('purchase', (_) => response.future);
      final first = NativeApplePaymentStore();
      final second = NativeApplePaymentStore();
      const product = AppleStoreProduct(productId, 'Points', 'HK\$38');
      final pending = first.buy(product, accountToken, consumable: true);
      expect(second.purchaseInFlight, isTrue);
      await expectLater(
        second.buy(product, accountToken, consumable: true),
        throwsStateError,
      );
      response.complete([pigeon.SK2ProductPurchaseResultMessage.userCancelled]);
      expect(await pending, AppleStorePurchaseResult.canceled);
      expect(second.purchaseInFlight, isFalse);
    },
  );
}
