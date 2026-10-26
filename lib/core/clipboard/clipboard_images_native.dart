import 'dart:async';

import 'package:flutter/services.dart';

import 'clipboard_image_validation.dart';
import 'clipboard_images_contract.dart';

const _channel = MethodChannel(clipboardImageChannelName);

ClipboardImageService createClipboardImageService() =>
    const NativeClipboardImageService();

ClipboardImagePasteBinding createClipboardImagePasteBinding({
  required bool Function() isFocused,
  required ClipboardImageCallback onImages,
  void Function(ClipboardImageException error)? onError,
}) => const _NativeClipboardImagePasteBinding();

final class NativeClipboardImageService implements ClipboardImageService {
  const NativeClipboardImageService();

  @override
  Future<List<ClipboardImagePayload>> readImagesFromUserPaste() async {
    try {
      final response = await _channel.invokeMethod<List<Object?>>('readImages');
      if (response == null || response.isEmpty) return const [];
      return validateClipboardImagePayloads(response.map(_payloadFromPlatform));
    } on ClipboardImageException {
      rethrow;
    } on PlatformException catch (error) {
      throw ClipboardImageException(_platformErrorCode(error.code));
    } on MissingPluginException {
      throw const ClipboardImageException('unavailable');
    } catch (_) {
      throw const ClipboardImageException('invalid_content');
    }
  }
}

ClipboardImagePayload _payloadFromPlatform(Object? value) {
  if (value is! Map) throw const ClipboardImageException('invalid_content');
  final data = Map<Object?, Object?>.from(value);
  final bytes = data['bytes'];
  if (data['name'] is! String ||
      data['mimeType'] is! String ||
      bytes is! Uint8List) {
    throw const ClipboardImageException('invalid_content');
  }
  return ClipboardImagePayload(
    name: data['name']! as String,
    mimeType: data['mimeType']! as String,
    bytes: bytes,
  );
}

String _platformErrorCode(String code) => switch (code) {
  'permission_denied' ||
  'empty' ||
  'unsupported_type' ||
  'image_too_large' ||
  'too_many_images' ||
  'total_too_large' ||
  'invalid_content' => code,
  _ => 'unavailable',
};

final class _NativeClipboardImagePasteBinding
    implements ClipboardImagePasteBinding {
  const _NativeClipboardImagePasteBinding();

  @override
  void setActive(bool active) {}

  @override
  void dispose() {}
}
