/// A short-lived, server-issued access session for the remote Harness.
///
/// The cookie value is secret and must only be persisted through
/// [HarnessAccessStorage]. [cacheNamespace] is deliberately non-sensitive and
/// lets authenticated media use a separate cache partition without exposing
/// the cookie.
class HarnessAccessSession {
  const HarnessAccessSession({
    required this.cookieValue,
    required this.origin,
    required this.expiresAt,
    required this.cacheNamespace,
  });

  static const cookieName = '__Host-popi-test';

  final String cookieValue;
  final String origin;
  final DateTime expiresAt;
  final String cacheNamespace;

  String get cookieHeader => '$cookieName=$cookieValue';

  bool isExpiredAt(DateTime instant) => !expiresAt.isAfter(instant.toUtc());

  Map<String, Object?> toJson() => {
    'cookieValue': cookieValue,
    'origin': origin,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'cacheNamespace': cacheNamespace,
  };

  factory HarnessAccessSession.fromJson(Map<String, Object?> json) {
    final cookieValue = json['cookieValue'];
    final originValue = json['origin'];
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final cacheNamespace = json['cacheNamespace'];
    final origin = originValue is String ? originValue : null;
    final parsedOrigin = origin == null ? null : Uri.tryParse(origin);
    if (cookieValue is! String ||
        cookieValue.isEmpty ||
        !_validCookieValue.hasMatch(cookieValue) ||
        origin == null ||
        parsedOrigin == null ||
        parsedOrigin.scheme != 'https' ||
        !parsedOrigin.hasAuthority ||
        parsedOrigin.origin != origin ||
        expiresAt == null ||
        cacheNamespace is! String ||
        !_uuid.hasMatch(cacheNamespace)) {
      throw const FormatException('Invalid Harness access session');
    }
    return HarnessAccessSession(
      cookieValue: cookieValue,
      origin: origin,
      expiresAt: expiresAt.toUtc(),
      cacheNamespace: cacheNamespace,
    );
  }

  @override
  String toString() =>
      'HarnessAccessSession(origin: $origin, expiresAt: $expiresAt, '
      'cacheNamespace: $cacheNamespace, cookieValue: <redacted>)';

  static final RegExp _validCookieValue = RegExp(r'^[^\s;,]+$');
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
}
