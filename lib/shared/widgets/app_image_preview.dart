import 'package:flutter/material.dart';

import '../type/media_preview_type.dart';
import 'app_media_gallery.dart';

export '../type/media_preview_type.dart';

/// Image-only entry points into the shared media gallery.
abstract final class AppImagePreview {
  static Future<void> show({
    required BuildContext context,
    required ImageProvider image,
    required Object heroTag,
    String? label,
  }) => showGallery(
    context: context,
    images: [ImagePreviewItem(image: image, heroTag: heroTag, label: label)],
  );

  static Future<void> showGallery({
    required BuildContext context,
    required List<ImagePreviewItem> images,
    int initialIndex = 0,
  }) => AppMediaGallery.show(
    context: context,
    items: images,
    initialIndex: initialIndex,
  );
}
