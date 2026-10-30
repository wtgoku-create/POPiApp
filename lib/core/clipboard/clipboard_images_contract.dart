import 'dart:async';
import 'dart:typed_data';

const clipboardImageChannelName = 'art.popi/clipboard_images';
const clipboardImageLimitBytes = 20 * 1024 * 1024;
const clipboardImageTotalLimitBytes = 20 * 1024 * 1024;
const clipboardImageCountLimit = 10;

final class ClipboardImagePayload {
  ClipboardImagePayload({
    required this.name,
    required this.mimeType,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

abstract interface class ClipboardImageService {
  /// Reads only in direct response to a user paste action.
  ///
  /// An empty list means that the clipboard contains no supported images;
  /// ordinary text paste should continue through the editable control.
  Future<List<ClipboardImagePayload>> readImagesFromUserPaste();
}

abstract interface class ClipboardImagePasteBinding {
  /// Web attaches its paste listener only while this binding is active.
  /// Native platforms use [ClipboardImageService] from their paste action.
  void setActive(bool active);

  void dispose();
}

final class ClipboardImageException implements Exception {
  const ClipboardImageException(this.code);

  final String code;

  @override
  String toString() => 'ClipboardImageException($code)';
}

typedef ClipboardImageCallback =
    FutureOr<void> Function(List<ClipboardImagePayload> images);
