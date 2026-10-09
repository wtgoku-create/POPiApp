import 'api_exception.dart';

/// Preserve order references even when the business response reports failure.
class PaymentException extends ApiException {
  const PaymentException({
    super.message,
    super.statusCode,
    this.code,
    this.data = const {},
  });

  final String? code;
  final Map<String, Object?> data;
}
