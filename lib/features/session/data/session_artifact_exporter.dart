import 'dart:convert';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/session_artifact.dart';

/// Exports the saved text version without fetching or regenerating its content.
abstract final class SessionArtifactExporter {
  static bool supports(SessionArtifact item) =>
      item.type == SessionArtifactType.script;

  static ({XFile file, String name}) document(SessionArtifact item) {
    if (!supports(item)) throw ArgumentError.value(item.type, 'type');
    final title = item.title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    var stem = String.fromCharCodes(title.runes.take(60));
    if (stem.isEmpty) stem = 'POPi_document';
    if (RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])($|\.)',
      caseSensitive: false,
    ).hasMatch(stem)) {
      stem = 'POPi_$stem';
    }
    final content = [
      item.summary,
      for (final shot in item.shots)
        '## ${shot.title}\n\n${shot.time}\n\n${shot.description}\n\n${shot.audio}',
    ].join('\n\n');
    final name = '$stem.md';
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

  /// Returns true only for a direct save; a mobile share sheet cannot confirm it.
  static Future<bool> save(
    SessionArtifact item, {
    required Rect sharePositionOrigin,
  }) async {
    final (:file, :name) = document(item);
    if (kIsWeb) {
      await file.saveTo(name);
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
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
}
