import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'demo_models.dart';

/// A validated, lazily-read file selected for the Harness asset library.
class DemoUploadFile {
  factory DemoUploadFile.fromBytes({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    final kind = kindForMimeType(mimeType);
    if (kind == null) throw const DemoUploadException('UNSUPPORTED_TYPE');
    validateMetadata(
      name: name,
      mimeType: mimeType,
      sizeBytes: bytes.lengthInBytes,
      kind: kind,
    );
    validateBytes(
      bytes,
      expectedSizeBytes: bytes.lengthInBytes,
      mimeType: mimeType,
      kind: kind,
    );
    final owned = Uint8List.fromList(bytes);
    final digest = sha256.convert(owned).toString();
    return DemoUploadFile(
      clientRequestId: requestIdFor(
        name: name,
        mimeType: mimeType,
        sha256: digest,
      ),
      name: name,
      mimeType: mimeType,
      sizeBytes: owned.lengthInBytes,
      kind: kind,
      expectedSha256: digest,
      readBytes: () async => Uint8List.fromList(owned),
    );
  }

  DemoUploadFile({
    String? clientRequestId,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.kind,
    this.expectedSha256,
    required Future<Uint8List> Function() readBytes,
  }) : clientRequestId = clientRequestId ?? const Uuid().v4(),
       _readBytes = readBytes {
    validateMetadata(
      name: name,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      kind: kind,
    );
  }

  final String clientRequestId;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final DemoAssetKind kind;
  final String? expectedSha256;
  final Future<Uint8List> Function() _readBytes;

  Future<Uint8List> readBytes() async {
    final bytes = await _readBytes();
    validateBytes(
      bytes,
      expectedSizeBytes: sizeBytes,
      mimeType: mimeType,
      kind: kind,
    );
    final expectedDigest = expectedSha256;
    if (expectedDigest != null &&
        sha256.convert(bytes).toString() != expectedDigest) {
      throw const DemoUploadException('INVALID_CONTENT');
    }
    return bytes;
  }

  static const int imageLimitBytes = 20 * 1024 * 1024;
  static const int videoLimitBytes = 128 * 1024 * 1024;
  static const int scriptLimitBytes = 2 * 1024 * 1024;
  static const int audioLimitBytes = 32 * 1024 * 1024;
  static const int documentLimitBytes = 20 * 1024 * 1024;
  static const int messageAttachmentLimit = 10;
  static const int messageAttachmentTotalLimitBytes = 50 * 1024 * 1024;
  static const int messageImageTotalLimitBytes = 20 * 1024 * 1024;
  static const int documentPageLimit = 100;
  static const int documentSlideLimit = 100;
  static const Set<String> documentMimeTypes = {
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  static bool isDocumentMimeType(String mimeType) =>
      documentMimeTypes.contains(mimeType);

  static DemoAssetKind? kindForMimeType(String mimeType) {
    for (final kind in DemoAssetKind.values) {
      if (_mimeTypesFor(kind).contains(mimeType)) return kind;
    }
    return null;
  }

  static String requestIdFor({
    required String name,
    required String mimeType,
    required String sha256,
  }) => const Uuid().v5(
    Namespace.url.value,
    'popi-upload\u0000$name\u0000$mimeType\u0000$sha256',
  );

  static void validateMessageAttachments(List<DemoAsset> assets) {
    if (assets.length > messageAttachmentLimit) {
      throw const DemoUploadException('ATTACHMENT_LIMIT');
    }
    if (assets.map((asset) => asset.id).toSet().length != assets.length) {
      throw const DemoUploadException('INVALID_ATTACHMENT');
    }
    var totalBytes = 0;
    var imageBytes = 0;
    for (final asset in assets) {
      totalBytes += asset.sizeBytes;
      if (asset.kind == DemoAssetKind.image) imageBytes += asset.sizeBytes;
    }
    if (totalBytes > messageAttachmentTotalLimitBytes ||
        imageBytes > messageImageTotalLimitBytes) {
      throw const DemoUploadException('ATTACHMENTS_TOO_LARGE');
    }
  }

  static int limitFor(DemoAssetKind kind, {String? mimeType}) => switch (kind) {
    DemoAssetKind.image => imageLimitBytes,
    DemoAssetKind.video => videoLimitBytes,
    DemoAssetKind.script =>
      isDocumentMimeType(mimeType ?? '')
          ? documentLimitBytes
          : scriptLimitBytes,
    DemoAssetKind.audio => audioLimitBytes,
  };

  static void validateMetadata({
    required String name,
    required String mimeType,
    required int sizeBytes,
    required DemoAssetKind kind,
  }) {
    if (name.trim().isEmpty ||
        name != name.split(RegExp(r'[/\\]')).last ||
        name.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      throw const DemoUploadException('INVALID_NAME');
    }
    if (!_mimeTypesFor(kind).contains(mimeType)) {
      throw const DemoUploadException('UNSUPPORTED_TYPE');
    }
    if (sizeBytes <= 0) {
      throw const DemoUploadException('EMPTY_FILE');
    }
    if (sizeBytes > limitFor(kind, mimeType: mimeType)) {
      throw const DemoUploadException('FILE_TOO_LARGE');
    }
  }

  static void validateBytes(
    Uint8List bytes, {
    required int expectedSizeBytes,
    required String mimeType,
    required DemoAssetKind kind,
  }) {
    if (bytes.isEmpty) throw const DemoUploadException('EMPTY_FILE');
    if (bytes.lengthInBytes != expectedSizeBytes) {
      throw const DemoUploadException('SIZE_MISMATCH');
    }
    if (!_mimeTypesFor(kind).contains(mimeType)) {
      throw const DemoUploadException('UNSUPPORTED_TYPE');
    }
    if (bytes.lengthInBytes > limitFor(kind, mimeType: mimeType)) {
      throw const DemoUploadException('FILE_TOO_LARGE');
    }
    if (!_contentMatches(bytes, mimeType)) {
      throw const DemoUploadException('INVALID_CONTENT');
    }
  }

  static Set<String> _mimeTypesFor(DemoAssetKind kind) => switch (kind) {
    DemoAssetKind.image => const {'image/png', 'image/jpeg', 'image/webp'},
    DemoAssetKind.video => const {'video/mp4'},
    DemoAssetKind.script => const {
      'text/plain',
      'text/markdown',
      ...documentMimeTypes,
    },
    DemoAssetKind.audio => const {'audio/mpeg', 'audio/wav', 'audio/mp4'},
  };

  static bool _contentMatches(Uint8List bytes, String mimeType) {
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

    return switch (mimeType) {
      'image/png' => startsWith(const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]),
      'image/jpeg' => startsWith(const [0xFF, 0xD8, 0xFF]),
      'image/webp' => hasAscii(0, 'RIFF') && hasAscii(8, 'WEBP'),
      'video/mp4' || 'audio/mp4' => hasAscii(4, 'ftyp'),
      'audio/mpeg' =>
        hasAscii(0, 'ID3') ||
            (bytes.length >= 2 &&
                bytes[0] == 0xFF &&
                (bytes[1] & 0xE0) == 0xE0),
      'audio/wav' => hasAscii(0, 'RIFF') && hasAscii(8, 'WAVE'),
      'text/plain' || 'text/markdown' => _isUtf8Text(bytes),
      'application/pdf' => hasAscii(0, '%PDF-'),
      'application/msword' || 'application/vnd.ms-powerpoint' => startsWith(
        const [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
      ),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
      'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
        startsWith(const [0x50, 0x4B, 0x03, 0x04]),
      _ => false,
    };
  }

  static bool _isUtf8Text(Uint8List bytes) {
    if (bytes.contains(0)) return false;
    try {
      utf8.decode(bytes, allowMalformed: false);
      return true;
    } on FormatException {
      return false;
    }
  }
}

class DemoUploadException implements Exception {
  const DemoUploadException(this.code, {this.acceptedFiles = const []});

  final String code;
  final List<DemoUploadFile> acceptedFiles;

  @override
  String toString() => 'DemoUploadException($code)';
}
