import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../utils/app_url.dart';
import 'network_api.dart';

/// Exchanges stable protected media paths for short-lived image URLs.
class MediaImageRepository {
  const MediaImageRepository(this._api);

  final NetworkApi _api;

  static String? protectedMediaId(String url) {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final uri = Uri.tryParse(AppUrl.resolve(url));
    if (uri == null) return null;
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.origin != base.origin ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.length != 6 ||
        segments[0] != 'api_client' ||
        segments[1] != 'agent' ||
        segments[2] != 'v2' ||
        segments[3] != 'media' ||
        segments[5] != 'content' ||
        int.tryParse(segments[4]) == null) {
      return null;
    }
    return segments[4];
  }

  Future<String> resolve(String url, {CancelToken? cancelToken}) {
    final id = protectedMediaId(url);
    return id == null
        ? Future.value(AppUrl.resolve(url, baseUrl: _api.mediaBaseUrl))
        : _api.mediaImageUrl(id, cancelToken: cancelToken);
  }
}
