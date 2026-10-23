import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/demo_models.dart';

/// Exports the original bundled demo file without making a backend request.
abstract final class DemoMediaExporter {
  static Future<int> size(DemoAsset asset) async =>
      (await rootBundle.load(asset.media)).lengthInBytes;

  static Future<bool> save(DemoAsset asset, Rect origin) async {
    final data = await rootBundle.load(asset.media);
    final extension = asset.media.split('.').last;
    final stem = asset.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    final name = '$stem.$extension';
    final file = XFile.fromData(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      name: name,
      mimeType: 'audio/mp4',
    );
    if (kIsWeb) {
      await file.saveTo(name);
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
      return false;
    }
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return false;
    await file.saveTo(location.path);
    return true;
  }
}
