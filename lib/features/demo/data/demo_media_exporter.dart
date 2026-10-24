import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/demo_models.dart';

/// Exports bundled media or caller-authorized bytes for remote demo assets.
abstract final class DemoMediaExporter {
  @visibleForTesting
  static Future<void> Function(ShareParams params)? debugShare;

  static Future<int> size(
    DemoAsset asset, {
    Future<Uint8List> Function()? readBytes,
  }) async {
    if (asset.isRemote) return asset.sizeBytes;
    return (await rootBundle.load(asset.media)).lengthInBytes;
  }

  static Future<bool> save(
    DemoAsset asset,
    Rect origin, {
    Future<Uint8List> Function()? readBytes,
  }) async {
    final Uint8List bytes;
    if (asset.isRemote) {
      if (readBytes == null) {
        throw StateError('Remote media requires an authenticated byte reader.');
      }
      bytes = await readBytes();
    } else {
      final data = await rootBundle.load(asset.media);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    final extension = asset.isRemote
        ? _remoteExtension(asset)
        : asset.media.split('.').last;
    final stem = asset.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    final name = '$stem.$extension';
    final file = XFile.fromData(
      bytes,
      name: name,
      mimeType: asset.isRemote
          ? _remoteMimeType(asset, extension)
          : 'audio/mp4',
    );
    if (kIsWeb) {
      await file.saveTo(name);
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      final params = ShareParams(
        files: [file],
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      );
      final share = debugShare;
      if (share == null) {
        await SharePlus.instance.share(params);
      } else {
        await share(params);
      }
      return false;
    }
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return false;
    await file.saveTo(location.path);
    return true;
  }

  static String displayExtension(DemoAsset asset) => asset.isRemote
      ? _remoteExtension(asset)
      : asset.media.split('.').last.toLowerCase();

  static String _remoteExtension(DemoAsset asset) {
    switch (_normalizedMimeType(asset.mimeType)) {
      case 'audio/mpeg':
      case 'audio/mp3':
        return 'mp3';
      case 'audio/wav':
      case 'audio/wave':
      case 'audio/x-wav':
        return 'wav';
      case 'audio/mp4':
      case 'audio/m4a':
      case 'audio/x-m4a':
        return 'm4a';
    }
    final path = Uri.tryParse(asset.contentUrl)?.path ?? asset.media;
    final extension = path.contains('.')
        ? path.split('.').last.toLowerCase()
        : '';
    return const {'mp3', 'wav', 'm4a'}.contains(extension) ? extension : 'm4a';
  }

  static String _remoteMimeType(DemoAsset asset, String extension) {
    final mimeType = _normalizedMimeType(asset.mimeType);
    if (mimeType.isNotEmpty) return mimeType;
    return switch (extension) {
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      _ => 'audio/mp4',
    };
  }

  static String _normalizedMimeType(String value) =>
      value.split(';').first.trim().toLowerCase();
}
