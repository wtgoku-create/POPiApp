import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final douyinLoginServiceProvider = Provider<DouyinLoginService>(
  (ref) => const DouyinLoginService(),
);

class DouyinLoginService {
  const DouyinLoginService();

  // Replace this adapter after Douyin SDK credentials and callbacks are ready.
  Future<DouyinAuthorizationResult> authorize() async =>
      const DouyinAuthorizationResult.unavailable();
}
