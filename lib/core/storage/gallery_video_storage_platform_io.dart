import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import 'gallery_image_storage.dart';
import 'gallery_video_too_large.dart';
import 'sensitive_media_headers.dart';

Future<void> save(
  Uri url, {
  CancelToken? cancelToken,
  Map<String, String> headers = const {},
  void Function()? onUnauthorized,
}) async {
  if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
    throw GalleryAccessDenied();
  }
  await withDownloadedVideo(
    url,
    Gal.putVideo,
    cancelToken: cancelToken,
    headers: headers,
    onUnauthorized: onUnauthorized,
  );
}

Future<T> withDownloadedVideo<T>(
  Uri url,
  Future<T> Function(String path) action, {
  CancelToken? cancelToken,
  Map<String, String> headers = const {},
  void Function()? onUnauthorized,
}) async {
  final path = await downloadForPlayback(
    url,
    cancelToken: cancelToken,
    headers: headers,
    onUnauthorized: onUnauthorized,
    maxBytes: 128 * 1024 * 1024,
  );
  try {
    return await action(path);
  } finally {
    await deleteDownloaded(path);
  }
}

Future<String> downloadForPlayback(
  Uri url, {
  CancelToken? cancelToken,
  Map<String, String> headers = const {},
  void Function()? onUnauthorized,
  required int maxBytes,
  String? fileExtension,
}) async {
  if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
  final directory = await Directory.systemTemp.createTemp('popi_video_');
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 2),
      followRedirects: !hasSensitiveMediaHeaders(headers),
      maxRedirects: hasSensitiveMediaHeaders(headers) ? 0 : 5,
    ),
  );
  try {
    final name = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    final extension = (fileExtension ?? name.split('.').last).toLowerCase();
    final suffix =
        {'mp4', 'mov', 'm4v', 'webm', 'mp3', 'wav', 'm4a'}.contains(extension)
        ? extension
        : 'mp4';
    final path = '${directory.path}/POPi_video.$suffix';
    if (url.scheme == 'asset') {
      final bytes = await rootBundle.load(url.path);
      if (bytes.lengthInBytes > maxBytes) {
        throw const GalleryVideoTooLarge();
      }
      if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
      await File(path).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } else {
      final response = await dio.get<ResponseBody>(
        url.toString(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers.isEmpty ? null : headers,
        ),
      );
      final body = response.data;
      if (body == null) throw StateError('Media response has no body');
      final contentLength = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      if (contentLength != null && contentLength > maxBytes) {
        throw const GalleryVideoTooLarge();
      }
      final sink = File(path).openWrite();
      var received = 0;
      try {
        await for (final chunk in body.stream) {
          if (cancelToken?.isCancelled ?? false) {
            throw cancelToken!.cancelError!;
          }
          received += chunk.length;
          if (received > maxBytes) throw const GalleryVideoTooLarge();
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
    }
    return path;
  } on DioException catch (error) {
    if (error.response?.statusCode == 401) onUnauthorized?.call();
    await directory.delete(recursive: true);
    rethrow;
  } on Object {
    await directory.delete(recursive: true);
    rethrow;
  } finally {
    dio.close(force: true);
  }
}

Future<void> deleteDownloaded(String path) async {
  final file = File(path);
  final directory = file.parent;
  final name = directory.uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .lastOrNull;
  if (name?.startsWith('popi_video_') == true && await directory.exists()) {
    await directory.delete(recursive: true);
  } else if (await file.exists()) {
    await file.delete();
  }
}
