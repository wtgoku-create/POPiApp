import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/purchase_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/type/payment_type.dart';
import '../../../shared/widgets/app_dialog.dart';

bool get usesApplePayments =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Show the localized StoreKit price before creating the purchase intent.
Future<StorePurchaseOutcome> openApplePayment(
  BuildContext context,
  WidgetRef ref, {
  required int? productVersionId,
  required PaymentProductKind kind,
}) async {
  if (!usesApplePayments) return StorePurchaseOutcome.unavailable;
  if (ref.read(userProvider) == null) {
    await context.push('/login');
    return StorePurchaseOutcome.canceled;
  }
  if (productVersionId == null) return StorePurchaseOutcome.productNotFound;
  final l10n = AppLocalizations.of(context)!;
  return ref
      .read(applePurchaseServiceProvider)
      .purchase(
        productVersionId: productVersionId,
        kind: kind,
        confirm: (product, grantPoints) async {
          if (!context.mounted) return false;
          return await AppDialog.confirm(
                context: context,
                title: l10n.paymentTitle,
                description: [
                  product.title,
                  product.price,
                  if (grantPoints != null) l10n.paymentGrantPoints(grantPoints),
                ].join('\n'),
                cancelLabel: l10n.cancel,
                confirmLabel: l10n.paymentConfirm,
              ) ??
              false;
        },
      );
}
