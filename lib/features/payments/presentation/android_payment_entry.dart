import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/user_provider.dart';
import '../domain/mobile_payment.dart';

bool get usesAndroidPayments =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Both purchase entry points share the same authenticated checkout route.
Future<bool> openAndroidPayment(
  BuildContext context,
  WidgetRef ref,
  PaymentProduct product,
) async {
  if (ref.read(userProvider) == null) {
    await context.push('/login');
    return false;
  }
  return await context.push<bool>('/payment/android', extra: product) ?? false;
}
