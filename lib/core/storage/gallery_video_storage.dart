import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

import 'gallery_image_storage.dart';

/// Streams remote videos to a temporary file before saving them to Photos.
abstract final class GalleryVideoStorage {
  static Future<void> save(Uri url, {CancelToken? cancelToken}) async {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw GalleryAccessDenied();
    }
    if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
    final directory = await Directory.systemTemp.createTemp('popi_video_');
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    try {
      final name = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
      final extension = name.split('.').last.toLowerCase();
      final suffix = {'mp4', 'mov', 'm4v', 'webm'}.contains(extension)
          ? extension
          : 'mp4';
      final path = '${directory.path}/POPi_video.$suffix';
      await dio.download(url.toString(), path, cancelToken: cancelToken);
      await Gal.putVideo(path);
    } finally {
      dio.close(force: true);
      await directory.delete(recursive: true);
    }
  }
}
