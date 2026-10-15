/// Mobile payment channels and server-confirmed outcomes.
enum PaymentChannel { wechat, alipay }

enum PaymentProductKind { subscription, points }

enum PaymentOutcome { completed, processing, canceled, failed, unknown }

/// Persisted Apple state; an interrupted native call is not a deferred payment.
enum ApplePurchasePhase { ready, launching, deferred, verifying, unknown }

enum AppleStorePurchaseResult {
  purchased,
  unverified,
  pending,
  canceled,
  notStarted,
}

enum StorePurchaseOutcome {
  purchased,
  processing,
  canceled,
  unavailable,
  productNotFound,
  failed,
}
