import 'package:file_selector/file_selector.dart';
import 'package:crypto/crypto.dart';

import '../domain/v2_models.dart';
import '../domain/v2_upload_file.dart';

const _v2AssetTypes = XTypeGroup(
  label: 'Images, videos, scripts, and audio',
  extensions: [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'mp4',
    'txt',
    'md',
    'mp3',
    'wav',
    'm4a',
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
  ],
  mimeTypes: [
    'image/png',
    'image/jpeg',
    'image/webp',
    'video/mp4',
    'text/plain',
    'text/markdown',
    'audio/mpeg',
    'audio/wav',
    'audio/mp4',
    ...V2UploadFile.documentMimeTypes,
  ],
  uniformTypeIdentifiers: [
    'public.png',
    'public.jpeg',
    'org.webmproject.webp',
    'public.mpeg-4',
    'public.plain-text',
    'net.daringfireball.markdown',
    'public.mp3',
    'com.microsoft.waveform-audio',
    'public.mpeg-4-audio',
    'com.adobe.pdf',
    'com.microsoft.word.doc',
    'org.openxmlformats.wordprocessingml.document',
    'com.microsoft.powerpoint.ppt',
    'org.openxmlformats.presentationml.presentation',
  ],
);

Future<List<V2UploadFile>> pickV2AssetFiles() async => v2UploadFilesFromXFiles(
  await openFiles(acceptedTypeGroups: const [_v2AssetTypes]),
);

/// Content-character uploads use the same validated transport, restricted to
/// image formats instead of the general asset library picker.
Future<List<V2UploadFile>> pickV2RoleImages() async {
  const images = XTypeGroup(
    label: 'Images',
    extensions: ['png', 'jpg', 'jpeg', 'webp'],
    mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
    uniformTypeIdentifiers: [
      'public.png',
      'public.jpeg',
      'org.webmproject.webp',
    ],
  );
  final selected = await v2UploadFilesFromXFiles(
    await openFiles(acceptedTypeGroups: const [images]),
  );
  final imageFiles = selected
      .where((file) => file.kind == V2AssetKind.image)
      .toList();
  if (imageFiles.length != selected.length) {
    throw V2UploadException('UNSUPPORTED_TYPE', acceptedFiles: imageFiles);
  }
  return imageFiles;
}

/// Validates metadata before streaming a bounded digest, avoiding a full body
/// allocation until upload begins.
Future<List<V2UploadFile>> v2UploadFilesFromXFiles(List<XFile> files) async {
  final result = <V2UploadFile>[];
  V2UploadException? firstError;
  for (final file in files) {
    try {
      final name = _fileName(file);
      final type = _typeForName(name);
      if (type == null) {
        throw const V2UploadException('UNSUPPORTED_TYPE');
      }
      final sizeBytes = await file.length();
      V2UploadFile.validateMetadata(
        name: name,
        mimeType: type.mimeType,
        sizeBytes: sizeBytes,
        kind: type.kind,
      );
      final digest = await sha256.bind(file.openRead(0, sizeBytes)).first;
      final digestText = digest.toString();
      final clientRequestId = V2UploadFile.requestIdFor(
        name: name,
        mimeType: type.mimeType,
        sha256: digestText,
      );
      result.add(
        V2UploadFile(
          clientRequestId: clientRequestId,
          name: name,
          mimeType: type.mimeType,
          sizeBytes: sizeBytes,
          kind: type.kind,
          expectedSha256: digestText,
          readBytes: file.readAsBytes,
        ),
      );
    } on V2UploadException catch (error) {
      firstError ??= error;
    } catch (_) {
      firstError ??= const V2UploadException('INVALID_CONTENT');
    }
  }
  if (firstError != null) {
    throw V2UploadException(firstError.code, acceptedFiles: result);
  }
  return result;
}

String _fileName(XFile file) {
  final name = file.name.trim();
  if (name.isNotEmpty) return name;
  return file.path.split(RegExp(r'[/\\]')).last;
}

({String mimeType, V2AssetKind kind})? _typeForName(String name) {
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'png' => (mimeType: 'image/png', kind: V2AssetKind.image),
    'jpg' || 'jpeg' => (mimeType: 'image/jpeg', kind: V2AssetKind.image),
    'webp' => (mimeType: 'image/webp', kind: V2AssetKind.image),
    'mp4' => (mimeType: 'video/mp4', kind: V2AssetKind.video),
    'txt' => (mimeType: 'text/plain', kind: V2AssetKind.script),
    'md' => (mimeType: 'text/markdown', kind: V2AssetKind.script),
    'mp3' => (mimeType: 'audio/mpeg', kind: V2AssetKind.audio),
    'wav' => (mimeType: 'audio/wav', kind: V2AssetKind.audio),
    'm4a' => (mimeType: 'audio/mp4', kind: V2AssetKind.audio),
    'pdf' => (mimeType: 'application/pdf', kind: V2AssetKind.script),
    'doc' => (mimeType: 'application/msword', kind: V2AssetKind.script),
    'docx' => (
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      kind: V2AssetKind.script,
    ),
    'ppt' => (
      mimeType: 'application/vnd.ms-powerpoint',
      kind: V2AssetKind.script,
    ),
    'pptx' => (
      mimeType:
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      kind: V2AssetKind.script,
    ),
    _ => null,
  };
}
