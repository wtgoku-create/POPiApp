import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';

void main() {
  test('uploaded audio retains playback metadata through the JSON cache', () {
    const asset = DemoAsset(
      id: 'uploaded-audio',
      title: '录音',
      kind: DemoAssetKind.audio,
      cover: '',
      contentUrl: 'http://127.0.0.1:3084/api_agent/v2/assets/audio/content',
      mimeType: 'audio/mpeg',
      durationSeconds: 12.375,
      hasAudio: true,
    );

    final restored = DemoAsset.fromJson(
      Map<String, Object?>.from(jsonDecode(jsonEncode(asset.toJson())) as Map),
    );

    expect(restored.durationSeconds, 12.375);
    expect(restored.hasAudio, isTrue);
    expect(restored.contentUrl, asset.contentUrl);
    expect(restored.mimeType, asset.mimeType);
  });
}
