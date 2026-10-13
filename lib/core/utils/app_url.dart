import '../config/app_config.dart';

/// Completes API resource paths without rewriting signed or local asset URLs.
abstract final class AppUrl {
  static String resolve(String value, {String baseUrl = AppConfig.apiBaseUrl}) {
    if (value.isEmpty || value.startsWith('assets/')) return value;
    final uri = Uri.tryParse(value);
    // Explicit schemes also include data URLs used by captcha images.
    if (uri == null || uri.hasScheme) return value;
    return Uri.parse(baseUrl).resolveUri(uri).toString();
  }

  static String? resolveNullable(
    String? value, {
    String baseUrl = AppConfig.apiBaseUrl,
  }) => value == null ? null : resolve(value, baseUrl: baseUrl);
}
