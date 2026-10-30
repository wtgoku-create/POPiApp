import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/network_agent_api.dart';
import '../domain/harness_access_session.dart';

enum HarnessAccessExceptionType {
  invalid,
  rateLimited,
  unavailable,
  invalidResponse,
}

class HarnessAccessException implements Exception {
  const HarnessAccessException(this.type, {this.retryAfterSeconds});

  final HarnessAccessExceptionType type;
  final int? retryAfterSeconds;

  bool get invalid => type == HarnessAccessExceptionType.invalid;
  bool get rateLimited => type == HarnessAccessExceptionType.rateLimited;

  @override
  String toString() =>
      'HarnessAccessException(type: $type, '
      'retryAfterSeconds: $retryAfterSeconds)';
}

class HarnessAccessRepository {
  HarnessAccessRepository(
    this.api, {
    required String origin,
    DateTime Function()? now,
    String Function()? createCacheNamespace,
  }) : origin = _cleanOrigin(origin),
       _now = now ?? DateTime.now,
       _createCacheNamespace = createCacheNamespace ?? const Uuid().v4 {
    final apiBase = Uri.tryParse(api.dio.options.baseUrl);
    if (apiBase == null ||
        apiBase.scheme != 'https' ||
        !apiBase.hasAuthority ||
        apiBase.userInfo.isNotEmpty ||
        apiBase.hasQuery ||
        apiBase.hasFragment ||
        apiBase.origin != this.origin) {
      throw StateError(
        'Harness login URL and Origin must share a clean HTTPS origin',
      );
    }
  }

  final NetworkAgentApi api;
  final String origin;
  final DateTime Function() _now;
  final String Function() _createCacheNamespace;

  Future<HarnessAccessSession> signIn({
    required String username,
    required String password,
  }) async {
    Response<Object?> response;
    try {
      response = await api.signInHarness(
        username: username,
        password: password,
      );
    } on DioException {
      throw const HarnessAccessException(
        HarnessAccessExceptionType.unavailable,
      );
    }

    switch (response.statusCode) {
      case 400:
        throw const HarnessAccessException(HarnessAccessExceptionType.invalid);
      case 429:
        throw HarnessAccessException(
          HarnessAccessExceptionType.rateLimited,
          retryAfterSeconds: _retryAfterSeconds(
            response.headers.value('retry-after'),
          ),
        );
      case 303:
        if (response.headers.value('location') == '/login?error=invalid') {
          throw const HarnessAccessException(
            HarnessAccessExceptionType.invalid,
          );
        }
        if (response.headers.value('location') != '/') {
          throw const HarnessAccessException(
            HarnessAccessExceptionType.invalidResponse,
          );
        }
        return _sessionFrom(response.headers);
      default:
        // In particular, a 302 must never be accepted as a successful login.
        throw const HarnessAccessException(
          HarnessAccessExceptionType.invalidResponse,
        );
    }
  }

  HarnessAccessSession _sessionFrom(Headers headers) {
    final values = headers.map['set-cookie'] ?? const <String>[];
    for (final value in values) {
      final session = _parseCookie(value);
      if (session != null) return session;
    }
    throw const HarnessAccessException(
      HarnessAccessExceptionType.invalidResponse,
    );
  }

  HarnessAccessSession? _parseCookie(String header) {
    final parts = header.split(';').map((value) => value.trim()).toList();
    if (parts.isEmpty) return null;
    final pair = parts.first;
    final separator = pair.indexOf('=');
    if (separator <= 0 ||
        pair.substring(0, separator) != HarnessAccessSession.cookieName) {
      return null;
    }
    final cookieValue = pair.substring(separator + 1);
    if (cookieValue.isEmpty || RegExp(r'[\s;,]').hasMatch(cookieValue)) {
      return null;
    }

    var secure = false;
    var httpOnly = false;
    var rootPath = false;
    var hasDomain = false;
    int? maxAge;
    DateTime? expires;
    for (final attribute in parts.skip(1)) {
      final attributeSeparator = attribute.indexOf('=');
      final name =
          (attributeSeparator < 0
                  ? attribute
                  : attribute.substring(0, attributeSeparator))
              .trim()
              .toLowerCase();
      final value = attributeSeparator < 0
          ? ''
          : attribute.substring(attributeSeparator + 1).trim();
      switch (name) {
        case 'secure':
          secure = true;
        case 'httponly':
          httpOnly = true;
        case 'path':
          rootPath = value == '/';
        case 'domain':
          hasDomain = true;
        case 'max-age':
          maxAge = int.tryParse(value);
        case 'expires':
          expires = _parseCookieDate(value);
      }
    }
    if (!secure || !httpOnly || !rootPath || hasDomain) return null;

    final now = _now().toUtc();
    DateTime? expiresAt;
    try {
      expiresAt = maxAge != null
          ? now.add(Duration(seconds: maxAge))
          : expires?.toUtc();
    } on Object {
      return null;
    }
    if (expiresAt == null || !expiresAt.isAfter(now)) return null;
    return HarnessAccessSession(
      cookieValue: cookieValue,
      origin: origin,
      expiresAt: expiresAt,
      cacheNamespace: _createCacheNamespace(),
    );
  }

  int? _retryAfterSeconds(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return seconds < 0 ? 0 : seconds;
    final retryAt = _parseCookieDate(value);
    if (retryAt == null) return null;
    final difference = retryAt.difference(_now().toUtc()).inSeconds;
    return difference < 0 ? 0 : difference;
  }

  static DateTime? _parseCookieDate(String value) {
    final match = RegExp(
      r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})[\s-]([A-Za-z]{3})[\s-](\d{2,4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final month = months[match.group(2)!.toLowerCase()];
    var year = int.tryParse(match.group(3)!);
    if (month == null || year == null) return null;
    if (year < 100) year += year >= 70 ? 1900 : 2000;
    try {
      final parsed = DateTime.utc(
        year,
        month,
        int.parse(match.group(1)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      );
      if (parsed.year != year ||
          parsed.month != month ||
          parsed.day != int.parse(match.group(1)!) ||
          parsed.hour != int.parse(match.group(4)!) ||
          parsed.minute != int.parse(match.group(5)!) ||
          parsed.second != int.parse(match.group(6)!)) {
        return null;
      }
      return parsed;
    } on FormatException {
      return null;
    }
  }

  static String _cleanOrigin(String value) {
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.origin != value) {
      throw StateError('Remote Harness access requires a clean HTTPS origin');
    }
    return uri.origin;
  }
}
