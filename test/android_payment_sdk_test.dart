import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluwx/fluwx.dart';
import 'package:fluwx/src/method_channel/fluwx_platform_interface.dart';

import 'package:popi_ai_app/core/config/app_config.dart';
import 'package:popi_ai_app/features/payments/data/android_payment_sdk.dart';
import 'package:popi_ai_app/features/payments/domain/mobile_payment.dart';
import 'package:popi_ai_app/shared/type/payment_type.dart';

class _WechatPlatform extends FluwxPlatform {
  final responses = StreamController<WeChatResponse>.broadcast();
  Payment? payment;
  int? callbackCode = 0;

  @override
  Stream<WeChatResponse> get responseEventHandler => responses.stream;

  @override
  Future<bool> pay(PayType which) async {
    payment = which as Payment;
    if (callbackCode != null) {
      responses.add(
        WeChatPaymentResponse.fromMap({'errCode': callbackCode, 'type': 5}),
      );
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.jarvanmo/tobias');
  late _WechatPlatform platform;
  late FluwxPlatform previous;
  late NativeAndroidPaymentSdk sdk;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const wechatOrder = MobilePaymentOrder(
    tradeNo: 'WX1',
    channel: PaymentChannel.wechat,
    payParams: {
      'appid': AppConfig.wechatAppId,
      'partnerid': 'merchant',
      'prepayid': 'prepay',
      'package': 'Sign=WXPay',
      'noncestr': 'nonce',
      'timestamp': '1710000000',
      'sign': 'signature',
    },
  );

  setUp(() {
    previous = FluwxPlatform.instance;
    platform = _WechatPlatform();
    FluwxPlatform.instance = platform;
    sdk = NativeAndroidPaymentSdk(wechat: Fluwx());
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await platform.responses.close();
    FluwxPlatform.instance = previous;
  });

  test('maps official WeChat parameters and its payment response', () async {
    expect(await sdk.pay(wechatOrder), PaymentSdkOutcome.returned);
    expect(platform.payment!.arguments, {
      'appId': AppConfig.wechatAppId,
      'partnerId': 'merchant',
      'prepayId': 'prepay',
      'packageValue': 'Sign=WXPay',
      'nonceStr': 'nonce',
      'timeStamp': 1710000000,
      'sign': 'signature',
      'signType': null,
      'extData': null,
    });
    platform.callbackCode = -2;
    expect(await sdk.pay(wechatOrder), PaymentSdkOutcome.canceled);
  });

  test('rejects WeChat parameters for another app before launch', () async {
    expect(
      await sdk.pay(
        MobilePaymentOrder(
          tradeNo: 'WX2',
          channel: PaymentChannel.wechat,
          payParams: {...wechatOrder.payParams, 'appid': 'another-app'},
        ),
      ),
      PaymentSdkOutcome.failed,
    );
    expect(platform.payment, isNull);
  });

  test(
    'passes Alipay signed data unchanged and treats cancellation as a hint',
    () async {
      const signed = 'a=1+b%2B&sign=xyz%3D';
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pay');
        expect((call.arguments as Map)['order'], signed);
        expect((call.arguments as Map)['payEnv'], 0);
        return {'resultStatus': '6001'};
      });
      expect(
        await sdk.pay(
          const MobilePaymentOrder(
            tradeNo: 'ALI1',
            channel: PaymentChannel.alipay,
            orderString: signed,
          ),
        ),
        PaymentSdkOutcome.canceled,
      );
    },
  );

  testWidgets(
    'resume without callback reconciles and releases WeChat listener',
    (tester) async {
      platform.callbackCode = null;
      final result = sdk.pay(wechatOrder);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      expect(await result, PaymentSdkOutcome.unknown);
      platform.callbackCode = 0;
      final second = sdk.pay(wechatOrder);
      await tester.pump();
      expect(await second, PaymentSdkOutcome.returned);
    },
  );
}
