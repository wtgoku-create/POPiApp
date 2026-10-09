import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fluwx/fluwx.dart';
import 'package:tobias/tobias.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/type/payment_type.dart';
import '../domain/mobile_payment.dart';

enum PaymentSdkOutcome { returned, canceled, failed, unknown }

/// SDK results are hints to start reconciliation, never proof of delivery.
abstract interface class AndroidPaymentSdk {
  Future<bool> available(PaymentChannel channel);
  Future<PaymentSdkOutcome> pay(MobilePaymentOrder order);
}

class NativeAndroidPaymentSdk implements AndroidPaymentSdk {
  NativeAndroidPaymentSdk({Fluwx? wechat, Tobias? alipay})
    : _wechat = wechat ?? _sharedWechat,
      _alipay = alipay ?? Tobias();

  final Fluwx _wechat;
  final Tobias _alipay;
  static final _sharedWechat = Fluwx();

  @override
  Future<bool> available(PaymentChannel channel) async {
    if (channel == PaymentChannel.alipay) return _alipay.isAliPayInstalled;
    if (AppConfig.wechatAppId.isEmpty) return false;
    return await _wechat.registerApi(
          appId: AppConfig.wechatAppId,
          universalLink: AppConfig.wechatUniversalLink,
        ) &&
        await _wechat.isWeChatInstalled;
  }

  @override
  Future<PaymentSdkOutcome> pay(MobilePaymentOrder order) async {
    final result = Completer<PaymentSdkOutcome>();
    Timer? resumeTimer;
    bool leftApp = false;
    // Returning without a native callback still starts server reconciliation.
    final lifecycle = AppLifecycleListener(
      onInactive: () => leftApp = true,
      onResume: () {
        if (!leftApp) return;
        resumeTimer?.cancel();
        resumeTimer = Timer(const Duration(seconds: 1), () {
          if (!result.isCompleted) result.complete(PaymentSdkOutcome.unknown);
        });
      },
    );
    unawaited(
      _launch(order, result.future).then(
        (outcome) {
          if (!result.isCompleted) result.complete(outcome);
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.complete(PaymentSdkOutcome.unknown);
        },
      ),
    );
    final timeout = Timer(const Duration(minutes: 2), () {
      if (!result.isCompleted) result.complete(PaymentSdkOutcome.unknown);
    });
    try {
      return await result.future;
    } finally {
      timeout.cancel();
      lifecycle.dispose();
      resumeTimer?.cancel();
    }
  }

  Future<PaymentSdkOutcome> _launch(
    MobilePaymentOrder order,
    Future<PaymentSdkOutcome> fallback,
  ) async {
    if (order.channel == PaymentChannel.wechat) {
      return _payWechat(order, fallback);
    }
    if (order.orderString.isEmpty) return PaymentSdkOutcome.failed;
    final result = await _alipay
        .pay(order.orderString)
        .timeout(
          const Duration(minutes: 2),
          onTimeout: () => <String, Object?>{},
        );
    return switch (result['resultStatus']?.toString()) {
      '9000' => PaymentSdkOutcome.returned,
      '6001' => PaymentSdkOutcome.canceled,
      '8000' || '6004' || null => PaymentSdkOutcome.unknown,
      _ => PaymentSdkOutcome.failed,
    };
  }

  Future<PaymentSdkOutcome> _payWechat(
    MobilePaymentOrder order,
    Future<PaymentSdkOutcome> fallback,
  ) async {
    final params = order.payParams;
    // WeChat's signed App parameters keep the official lower-case key names.
    String value(String key) => params[key]?.toString() ?? '';
    final timestamp = paymentInteger(params['timestamp']);
    if (value('appid') != AppConfig.wechatAppId ||
        const [
          'partnerid',
          'prepayid',
          'package',
          'noncestr',
          'sign',
        ].any((key) => value(key).isEmpty) ||
        timestamp == null) {
      return PaymentSdkOutcome.failed;
    }
    final result = Completer<PaymentSdkOutcome>();
    final subscriber = _wechat.addSubscriber((response) {
      if (response is! WeChatPaymentResponse || result.isCompleted) return;
      result.complete(switch (response.errCode) {
        0 => PaymentSdkOutcome.returned,
        -2 => PaymentSdkOutcome.canceled,
        _ => PaymentSdkOutcome.failed,
      });
    });
    try {
      final launched = await _wechat.pay(
        which: Payment(
          appId: value('appid'),
          partnerId: value('partnerid'),
          prepayId: value('prepayid'),
          packageValue: value('package'),
          nonceStr: value('noncestr'),
          timestamp: timestamp,
          sign: value('sign'),
        ),
      );
      if (!launched) return PaymentSdkOutcome.failed;
      return await Future.any([result.future, fallback]);
    } finally {
      subscriber.cancel();
    }
  }
}
