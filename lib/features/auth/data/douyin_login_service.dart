import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';

enum DouyinAuthorizationStatus { authorized, canceled, unavailable, failed }

class DouyinAuthorizationResult {
  const DouyinAuthorizationResult._(this.status, {this.code});

  const DouyinAuthorizationResult.authorized(String code)
    : this._(DouyinAuthorizationStatus.authorized, code: code);

  const DouyinAuthorizationResult.canceled()
    : this._(DouyinAuthorizationStatus.canceled);

  const DouyinAuthorizationResult.unavailable()
    : this._(DouyinAuthorizationStatus.unavailable);

  const DouyinAuthorizationResult.failed()
    : this._(DouyinAuthorizationStatus.failed);

  final DouyinAuthorizationStatus status;
  final String? code;
}

/// Bridges native Douyin authorization to the backend's one-time code login.
class DouyinLoginService {
  const DouyinLoginService({
    this.clientKey = AppConfig.douyinClientKey,
    this.universalLink = AppConfig.douyinUniversalLink,
    this.timeout = const Duration(minutes: 2),
  });

  static const _channel = MethodChannel('art.popi/douyin_login');
  final String clientKey;
  final String universalLink;
  final Duration timeout;

  Future<DouyinAuthorizationResult> authorize() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        clientKey.trim().isEmpty) {
      return const DouyinAuthorizationResult.unavailable();
    }
    final state = const Uuid().v4();
    try {
      final response = await _channel
          .invokeMapMethod<String, Object?>('authorize', {
            'clientKey': clientKey,
            'universalLink': universalLink,
            'state': state,
          })
          .timeout(timeout);
      if (kDebugMode) {
        debugPrint(
          'Douyin authorization: status=${response?['status']}, '
          'reason=${response?['reason']}, errorCode=${response?['errorCode']}, '
          'stateMatches=${response?['stateMatches']}',
        );
      }
      switch (response?['status']) {
        case 'authorized':
          final code = response?['code'];
          if (response?['state'] == state &&
              code is String &&
              code.trim().isNotEmpty) {
            return DouyinAuthorizationResult.authorized(code.trim());
          }
          return const DouyinAuthorizationResult.failed();
        case 'canceled':
          return const DouyinAuthorizationResult.canceled();
        case 'unavailable':
          return const DouyinAuthorizationResult.unavailable();
        default:
          return const DouyinAuthorizationResult.failed();
      }
    } on TimeoutException {
      try {
        await _channel.invokeMethod<void>('cancelAuthorization', {
          'state': state,
        });
      } on PlatformException {
        // The result has already timed out; cleanup must not hide that result.
      } on MissingPluginException {
        return const DouyinAuthorizationResult.unavailable();
      }
      return const DouyinAuthorizationResult.failed();
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('Douyin native channel is missing; rebuild the iOS app.');
      }
      return const DouyinAuthorizationResult.unavailable();
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Douyin platform error: ${error.code}');
      }
      return const DouyinAuthorizationResult.failed();
    }
  }
}
