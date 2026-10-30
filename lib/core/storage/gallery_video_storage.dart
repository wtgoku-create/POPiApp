import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import 'gallery_video_storage_platform_stub.dart'
    if (dart.library.io) 'gallery_video_storage_platform_io.dart'
    as platform;

export 'gallery_video_too_large.dart';

import 'gallery_video_too_large.dart';
import 'sensitive_media_headers.dart';

@immutable
class DownloadedVideo {
  const DownloadedVideo({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
}

@immutable
class WebVideoDownload {
  const WebVideoDownload({
    required this.url,
    required this.name,
    required this.mimeType,
  });

  final Uri url;
  final String name;
  final String mimeType;
}

/// Saves videos to Photos on native platforms and as files in the browser.
abstract final class GalleryVideoStorage {
  static const maxShareBytes = 32 * 1024 * 1024;
  static const maxProtectedMediaBytes = 128 * 1024 * 1024;

  @visibleForTesting
  static int debugMaxShareBytes = maxShareBytes;

  @visibleForTesting
  static Future<void> Function(WebVideoDownload download)? debugWebDownload;

  @visibleForTesting
  static Future<String> Function(
    Uri url,
    Map<String, String> headers,
    void Function()? onUnauthorized,
    String? fileExtension,
  )?
  debugPlaybackDownload;

  @visibleForTesting
  static Future<void> Function(String path)? debugDeleteDownloaded;

  static Future<void> save(
    Uri url, {
    CancelToken? cancelToken,
    Map<String, String> headers = const {},
    void Function()? onUnauthorized,
  }) async {
    final webDownload = debugWebDownload;
    if (kIsWeb || webDownload != null) {
      if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
      final extension = _extension(url);
      final download = WebVideoDownload(
        url: url,
        name: 'POPi_video_${DateTime.now().millisecondsSinceEpoch}.$extension',
        mimeType: _mimeType(extension),
      );
      await (webDownload ?? _downloadWeb)(download);
      return;
    }
    await platform.save(
      url,
      cancelToken: cancelToken,
      headers: headers,
      onUnauthorized: onUnauthorized,
    );
  }

  /// Downloads bounded bytes for browser share actions.
  static Future<DownloadedVideo> downloadForShare(
    Uri url, {
    CancelToken? cancelToken,
    Map<String, String> headers = const {},
    void Function()? onUnauthorized,
  }) async {
    if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
        followRedirects: !hasSensitiveMediaHeaders(headers),
        maxRedirects: hasSensitiveMediaHeaders(headers) ? 0 : 5,
      ),
    );
    try {
      final response = await dio.get<ResponseBody>(
        url.toString(),
        options: Options(
          responseType: ResponseType.stream,
          headers: kIsWeb || headers.isEmpty ? null : headers,
        ),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) throw StateError('Video response has no body');
      final contentLength = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      if (contentLength != null && contentLength > debugMaxShareBytes) {
        throw const GalleryVideoTooLarge();
      }
      final output = BytesBuilder(copy: false);
      var length = 0;
      await for (final chunk in body.stream) {
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
        length += chunk.length;
        if (length > debugMaxShareBytes) throw const GalleryVideoTooLarge();
        output.add(chunk);
      }
      if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
      final extension = _extension(url);
      return DownloadedVideo(
        bytes: output.takeBytes(),
        name: 'POPi_video_${DateTime.now().millisecondsSinceEpoch}.$extension',
        mimeType: _mimeType(extension),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) onUnauthorized?.call();
      rethrow;
    } finally {
      dio.close(force: true);
    }
  }

  /// Keeps a downloaded native file alive for an action, then removes it.
  static Future<T> withDownloadedVideo<T>(
    Uri url,
    Future<T> Function(String path) action, {
    CancelToken? cancelToken,
    Map<String, String> headers = const {},
    void Function()? onUnauthorized,
  }) => platform.withDownloadedVideo(
    url,
    action,
    cancelToken: cancelToken,
    headers: headers,
    onUnauthorized: onUnauthorized,
  );

  /// Downloads protected media without allowing the HTTP client to redirect
  /// credentials. The caller owns the returned file until [deleteDownloaded].
  static Future<String> downloadForPlayback(
    Uri url, {
    CancelToken? cancelToken,
    Map<String, String> headers = const {},
    void Function()? onUnauthorized,
    String? fileExtension,
  }) {
    final debug = debugPlaybackDownload;
    if (debug != null) {
      return debug(url, headers, onUnauthorized, fileExtension);
    }
    return platform.downloadForPlayback(
      url,
      cancelToken: cancelToken,
      headers: headers,
      onUnauthorized: onUnauthorized,
      maxBytes: maxProtectedMediaBytes,
      fileExtension: fileExtension,
    );
  }

  static Future<void> deleteDownloaded(String path) =>
      debugDeleteDownloaded?.call(path) ?? platform.deleteDownloaded(path);

  static Future<void> _downloadWeb(WebVideoDownload download) => XFile(
    download.url.toString(),
    name: download.name,
    mimeType: download.mimeType,
  ).saveTo(download.name);

  static String _extension(Uri url) {
    final name = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    final extension = name.split('.').last.toLowerCase();
    return {'mp4', 'mov', 'm4v', 'webm'}.contains(extension)
        ? extension
        : 'mp4';
  }

  static String _mimeType(String extension) => switch (extension) {
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'video/mp4',
  };
}
