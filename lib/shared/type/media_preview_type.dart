import 'package:flutter/painting.dart';

/// One item in an ordered image/video preview gallery.
sealed class MediaPreviewItem {
  const MediaPreviewItem({required this.heroTag, this.label});

  final Object heroTag;
  final String? label;
  ImageProvider? get previewImage;
}

/// One full-resolution image and its matching source thumbnail transition.
class ImagePreviewItem extends MediaPreviewItem {
  const ImagePreviewItem({
    required this.image,
    required super.heroTag,
    super.label,
  });

  final ImageProvider image;
  @override
  ImageProvider get previewImage => image;
}

/// A playable video with an optional cover image.
class VideoPreviewItem extends MediaPreviewItem {
  const VideoPreviewItem({
    required this.url,
    required super.heroTag,
    this.thumbnail,
    super.label,
  });

  final Uri url;
  final ImageProvider? thumbnail;
  @override
  ImageProvider? get previewImage => thumbnail;
}
