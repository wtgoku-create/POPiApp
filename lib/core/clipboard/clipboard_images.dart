import 'dart:async';

import 'clipboard_images_contract.dart';
import 'clipboard_images_native.dart'
    if (dart.library.js_interop) 'clipboard_images_web.dart'
    as implementation;

export 'clipboard_images_contract.dart';

ClipboardImageService createClipboardImageService() =>
    implementation.createClipboardImageService();

ClipboardImagePasteBinding createClipboardImagePasteBinding({
  required bool Function() isFocused,
  required FutureOr<void> Function(List<ClipboardImagePayload> images) onImages,
  void Function(ClipboardImageException error)? onError,
}) => implementation.createClipboardImagePasteBinding(
  isFocused: isFocused,
  onImages: onImages,
  onError: onError,
);
