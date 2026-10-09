import 'package:flutter/material.dart';

import 'app_media_preview.dart';

/// Opens an image in the shared media preview page.
abstract final class AppImagePreview {
  static Future<void> show({
    required BuildContext context,
    required ImageProvider image,
    required Object heroTag,
    String? label,
  }) => AppMediaPreview.showImage(
    context: context,
    image: image,
    heroTag: heroTag,
    label: label,
  );
}
