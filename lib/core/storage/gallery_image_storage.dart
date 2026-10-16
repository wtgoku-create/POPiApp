import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:gal/gal.dart';

class GalleryAccessDenied implements Exception {}

/// Saves full-resolution decoded images, reusing Flutter's image cache.
abstract final class GalleryImageStorage {
  static Future<void> save(
    ImageProvider provider,
    ImageConfiguration configuration,
  ) async {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw GalleryAccessDenied();
    }
    await Gal.putImageBytes(
      await readPng(provider, configuration),
      name: 'POPi_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Reads the original decoded image for saving or sharing, without a screenshot.
  static Future<Uint8List> readPng(
    ImageProvider provider,
    ImageConfiguration configuration,
  ) async {
    final stream = provider.resolve(configuration);
    final completer = Completer<ImageInfo>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(info);
        } else {
          info.dispose();
        }
      },
      onError: (Object error, StackTrace? stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    ImageInfo? info;
    try {
      info = await completer.future;
      final bytes = await info.image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Cannot encode image');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      stream.removeListener(listener);
      info?.dispose();
    }
  }
}
