import 'dart:typed_data';

import 'clipboard_images_contract.dart';

const _supportedTypes = {'image/png', 'image/jpeg', 'image/webp'};

List<ClipboardImagePayload> validateClipboardImagePayloads(
  Iterable<ClipboardImagePayload> values,
) {
  final input = values.toList(growable: false);
  if (input.length > clipboardImageCountLimit) {
    throw const ClipboardImageException('too_many_images');
  }
  var total = 0;
  final output = <ClipboardImagePayload>[];
  for (var index = 0; index < input.length; index++) {
    final value = input[index];
    if (value.bytes.isEmpty) {
      throw const ClipboardImageException('empty');
    }
    if (value.bytes.lengthInBytes > clipboardImageLimitBytes) {
      throw const ClipboardImageException('image_too_large');
    }
    total += value.bytes.lengthInBytes;
    if (total > clipboardImageTotalLimitBytes) {
      throw const ClipboardImageException('total_too_large');
    }
    final declared = _normalizedMimeType(value.mimeType);
    final detected = _detectedMimeType(value.bytes);
    if (declared != null && !_supportedTypes.contains(declared)) {
      throw const ClipboardImageException('unsupported_type');
    }
    final mimeType = declared ?? detected;
    if (mimeType == null || detected != mimeType) {
      throw const ClipboardImageException('invalid_content');
    }
    output.add(
      ClipboardImagePayload(
        name: _safeName(value.name, mimeType, index),
        mimeType: mimeType,
        bytes: value.bytes,
      ),
    );
  }
  return List.unmodifiable(output);
}

String? _normalizedMimeType(String value) {
  final type = value.trim().toLowerCase().split(';').first;
  return switch (type) {
    '' || 'application/octet-stream' => null,
    'image/jpg' => 'image/jpeg',
    _ => type,
  };
}

String? _detectedMimeType(Uint8List bytes) {
  bool startsWith(List<int> signature) =>
      bytes.length >= signature.length &&
      Iterable<int>.generate(
        signature.length,
      ).every((index) => bytes[index] == signature[index]);
  bool hasAscii(int offset, String value) =>
      bytes.length >= offset + value.length &&
      Iterable<int>.generate(
        value.length,
      ).every((index) => bytes[offset + index] == value.codeUnitAt(index));
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (hasAscii(0, 'RIFF') && hasAscii(8, 'WEBP')) return 'image/webp';
  return null;
}

String _safeName(String value, String mimeType, int index) {
  final leaf = value.trim().split(RegExp(r'[/\\]')).last;
  if (leaf.isNotEmpty && !leaf.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
    return leaf;
  }
  final extension = switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    _ => 'png',
  };
  return 'clipboard-image-${index + 1}.$extension';
}
