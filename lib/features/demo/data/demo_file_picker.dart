import 'package:file_selector/file_selector.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../domain/demo_models.dart';
import '../domain/demo_upload_file.dart';

const _demoAssetTypes = XTypeGroup(
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
  ],
);

Future<List<DemoUploadFile>> pickDemoAssetFiles() async =>
    demoUploadFilesFromXFiles(
      await openFiles(acceptedTypeGroups: const [_demoAssetTypes]),
    );

/// Content-character uploads use the same validated transport, restricted to
/// image formats instead of the general asset library picker.
Future<List<DemoUploadFile>> pickDemoRoleImages() async {
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
  final selected = await demoUploadFilesFromXFiles(
    await openFiles(acceptedTypeGroups: const [images]),
  );
  final imageFiles = selected
      .where((file) => file.kind == DemoAssetKind.image)
      .toList();
  if (imageFiles.length != selected.length) {
    throw DemoUploadException('UNSUPPORTED_TYPE', acceptedFiles: imageFiles);
  }
  return imageFiles;
}

/// Validates metadata before streaming a bounded digest, avoiding a full body
/// allocation until upload begins.
Future<List<DemoUploadFile>> demoUploadFilesFromXFiles(
  List<XFile> files,
) async {
  final result = <DemoUploadFile>[];
  DemoUploadException? firstError;
  for (final file in files) {
    try {
      final name = _fileName(file);
      final type = _typeForName(name);
      if (type == null) {
        throw const DemoUploadException('UNSUPPORTED_TYPE');
      }
      final sizeBytes = await file.length();
      DemoUploadFile.validateMetadata(
        name: name,
        mimeType: type.mimeType,
        sizeBytes: sizeBytes,
        kind: type.kind,
      );
      final digest = await sha256.bind(file.openRead(0, sizeBytes)).first;
      final digestText = digest.toString();
      final clientRequestId = const Uuid().v5(
        Namespace.url.value,
        'popi-upload\u0000$name\u0000${type.mimeType}\u0000$digestText',
      );
      result.add(
        DemoUploadFile(
          clientRequestId: clientRequestId,
          name: name,
          mimeType: type.mimeType,
          sizeBytes: sizeBytes,
          kind: type.kind,
          expectedSha256: digestText,
          readBytes: file.readAsBytes,
        ),
      );
    } on DemoUploadException catch (error) {
      firstError ??= error;
    } catch (_) {
      firstError ??= const DemoUploadException('INVALID_CONTENT');
    }
  }
  if (firstError != null) {
    throw DemoUploadException(firstError.code, acceptedFiles: result);
  }
  return result;
}

String _fileName(XFile file) {
  final name = file.name.trim();
  if (name.isNotEmpty) return name;
  return file.path.split(RegExp(r'[/\\]')).last;
}

({String mimeType, DemoAssetKind kind})? _typeForName(String name) {
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'png' => (mimeType: 'image/png', kind: DemoAssetKind.image),
    'jpg' || 'jpeg' => (mimeType: 'image/jpeg', kind: DemoAssetKind.image),
    'webp' => (mimeType: 'image/webp', kind: DemoAssetKind.image),
    'mp4' => (mimeType: 'video/mp4', kind: DemoAssetKind.video),
    'txt' => (mimeType: 'text/plain', kind: DemoAssetKind.script),
    'md' => (mimeType: 'text/markdown', kind: DemoAssetKind.script),
    'mp3' => (mimeType: 'audio/mpeg', kind: DemoAssetKind.audio),
    'wav' => (mimeType: 'audio/wav', kind: DemoAssetKind.audio),
    'm4a' => (mimeType: 'audio/mp4', kind: DemoAssetKind.audio),
    _ => null,
  };
}
