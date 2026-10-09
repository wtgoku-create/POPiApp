import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/purchase_provider.dart';
import '../../../shared/type/payment_type.dart';
import '../../../shared/widgets/app_dialog.dart';

bool get usesApplePayments =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Show the localized StoreKit price before creating the purchase intent.
Future<StorePurchaseOutcome> openApplePayment(
  BuildContext context,
  WidgetRef ref, {
  required int productId,
  required PaymentProductKind kind,
}) {
  final l10n = AppLocalizations.of(context)!;
  return ref
      .read(applePurchaseServiceProvider)
      .purchase(
        businessProductId: productId,
        kind: kind,
        confirm: (product) async {
          if (!context.mounted) return false;
          return await AppDialog.confirm(
                context: context,
                title: l10n.paymentTitle,
                description: '${product.title}\n${product.price}',
                cancelLabel: l10n.cancel,
                confirmLabel: l10n.paymentConfirm,
              ) ??
              false;
        },
      );
}
