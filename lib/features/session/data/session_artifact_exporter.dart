import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/app_image_cache.dart';
import '../../../core/storage/gallery_image_storage.dart';
import '../../../core/storage/gallery_video_storage.dart';
import '../domain/session_artifact.dart';
import 'session_repository.dart';

/// Exports saved documents and resolves original media only when saving.
abstract final class SessionArtifactExporter {
  static bool supports(SessionArtifact item) =>
      item.type == SessionArtifactType.script ||
      (item.type == SessionArtifactType.image &&
          (item.mediaId != null || item.previewAsset != null)) ||
      (item.type == SessionArtifactType.video &&
          (item.mediaId != null || item.videoUrl != null));

  static String _fileName(SessionArtifact item, String extension) {
    final title = item.title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    var stem = String.fromCharCodes(title.runes.take(60));
    if (stem.isEmpty) {
      stem = item.type == SessionArtifactType.script
          ? 'POPi_document'
          : 'POPi_${item.type.name}';
    }
    if (RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])($|\.)',
      caseSensitive: false,
    ).hasMatch(stem)) {
      stem = 'POPi_$stem';
    }
    return '$stem.$extension';
  }

  static ({XFile file, String name}) document(SessionArtifact item) {
    if (item.type != SessionArtifactType.script) {
      throw ArgumentError.value(item.type, 'type');
    }
    final content = [
      item.summary,
      for (final shot in item.shots)
        '## ${shot.title}\n\n${shot.time}\n\n${shot.description}\n\n${shot.audio}',
    ].join('\n\n');
    final name = _fileName(item, 'md');
    // Native XFile implementations ignore name, so keep it for the save dialog.
    return (
      file: XFile.fromData(
        Uint8List.fromList(utf8.encode(content)),
        name: name,
        mimeType: 'text/markdown',
      ),
      name: name,
    );
  }

  /// Returns true only for a completed save; document sharing cannot confirm it.
  static Future<bool> save(
    SessionArtifact item, {
    required Rect sharePositionOrigin,
    SessionRepository? repository,
    ImageConfiguration imageConfiguration = const ImageConfiguration(),
    CancelToken? cancelToken,
  }) async {
    if (!supports(item)) throw ArgumentError.value(item.type, 'type');
    if (item.type != SessionArtifactType.script) {
      final media = item.mediaId == null
          ? null
          : await repository!.media(item.mediaId!, cancelToken: cancelToken);
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      if (item.type == SessionArtifactType.video) {
        final url = media == null ? item.videoUrl! : Uri.parse(media.url);
        if (_mobile) {
          await GalleryVideoStorage.save(url, cancelToken: cancelToken);
          return true;
        }
        final extension = url.pathSegments.lastOrNull
            ?.split('.')
            .last
            .toLowerCase();
        final name = _fileName(
          item,
          {'mp4', 'mov', 'm4v', 'webm'}.contains(extension)
              ? extension!
              : 'mp4',
        );
        final location = await getSaveLocation(suggestedName: name);
        if (location == null) return false;
        return GalleryVideoStorage.withDownloadedVideo(url, (path) async {
          await XFile(path).saveTo(location.path);
          return true;
        }, cancelToken: cancelToken);
      }
      final ImageProvider image = media == null
          ? AssetImage(item.previewAsset!)
          : AppImageCache.provider(media.url);
      if (_mobile) {
        await GalleryImageStorage.save(image, imageConfiguration);
        return true;
      }
      final name = _fileName(item, 'png');
      final location = await getSaveLocation(suggestedName: name);
      if (location == null) return false;
      final bytes = await GalleryImageStorage.readPng(
        image,
        imageConfiguration,
      );
      await XFile.fromData(bytes, mimeType: 'image/png').saveTo(location.path);
      return true;
    }
    final (:file, :name) = document(item);
    if (kIsWeb) {
      await file.saveTo(name);
      return true;
    }
    if (_mobile) {
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [name],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return false;
    }
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return false;
    await file.saveTo(location.path);
    return true;
  }

  static bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
