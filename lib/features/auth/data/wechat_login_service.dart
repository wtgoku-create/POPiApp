import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fluwx/fluwx.dart';

enum WechatAuthorizationStatus { authorized, canceled, unavailable, failed }

class WechatAuthorizationResult {
  const WechatAuthorizationResult._(this.status, {this.code});

  const WechatAuthorizationResult.authorized(String code)
      : this._(WechatAuthorizationStatus.authorized, code: code);

  const WechatAuthorizationResult.canceled()
      : this._(WechatAuthorizationStatus.canceled);

  const WechatAuthorizationResult.unavailable()
      : this._(WechatAuthorizationStatus.unavailable);

  const WechatAuthorizationResult.failed()
      : this._(WechatAuthorizationStatus.failed);

  final WechatAuthorizationStatus status;
  final String? code;
}

class WechatLoginService {
  WechatLoginService({Fluwx? fluwx}) : _fluwx = fluwx ?? _sharedFluwx;

  static const appId = String.fromEnvironment(
    'WECHAT_APP_ID',
    defaultValue: 'wxf99ad5d5c7b4fe37',
  );
  static const universalLink = String.fromEnvironment(
    'WECHAT_UNIVERSAL_LINK',
    defaultValue: 'https://app.popi.art/WeChat/',
  );
  static final _sharedFluwx = Fluwx();

  final Fluwx _fluwx;

  Future<WechatAuthorizationResult> authorize() async {
    if (appId.trim().isEmpty) {
      return const WechatAuthorizationResult.unavailable();
    }

    final registered = await _fluwx.registerApi(
      appId: appId,
      universalLink: universalLink,
    );
    if (!registered) return const WechatAuthorizationResult.failed();
    if (!await _fluwx.isWeChatInstalled) {
      return const WechatAuthorizationResult.unavailable();
    }

    final completer = Completer<WechatAuthorizationResult>();
    late final FluwxCancelable subscriber;
    subscriber = _fluwx.addSubscriber((response) {
      if (response is! WeChatAuthResponse || completer.isCompleted) return;
      final code = response.code?.trim();
      if (kDebugMode) {
        debugPrint(
          'WeChat authorization response: '
          'errCode=${response.errCode}, hasCode=${code?.isNotEmpty ?? false}',
        );
      }
      if (response.errCode == 0 && code != null && code.isNotEmpty) {
        completer.complete(WechatAuthorizationResult.authorized(code));
      } else if (response.errCode == -2) {
        completer.complete(const WechatAuthorizationResult.canceled());
      } else {
        completer.complete(const WechatAuthorizationResult.failed());
      }
    });

    try {
      final started = await _fluwx.authBy(
        which: NormalAuth(scope: 'snsapi_userinfo'),
      );
      if (!started) return const WechatAuthorizationResult.failed();
      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => const WechatAuthorizationResult.failed(),
      );
    } finally {
      subscriber.cancel();
    }
  }
}
