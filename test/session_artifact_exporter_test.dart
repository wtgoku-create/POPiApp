import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/data/session_artifact_exporter.dart';
import 'package:popi_ai_app/features/session/domain/session_artifact.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const origin = Rect.fromLTWH(10, 20, 40, 40);
  final item = SessionArtifact.fromTextDraft({
    'id': 'text',
    'title': '选题：测试/环境?',
    'content': '## 故事正文\n\n中文、emoji 😀，以及 **Markdown**。',
  });

  test(
    'document preserves Unicode and Markdown and sanitizes its file name',
    () async {
      final document = SessionArtifactExporter.document(item);
      expect(document.name, '选题：测试_环境_.md');
      expect(document.file.mimeType, 'text/markdown');
      expect(await document.file.readAsString(), item.summary);
      for (final title in ['', '..', 'CON', 'LPT1.txt', '😀' * 100]) {
        final document = SessionArtifactExporter.document(
          SessionArtifact.fromTextDraft({'id': 'text', 'title': title}),
        );
        expect(document.name, isNot('.md'));
        expect(document.name.length, lessThan(130));
        expect(document.name, isNot('CON.md'));
        expect(document.name, isNot('LPT1.txt.md'));
      }
    },
  );

  test(
    'legacy storyboard includes every shot in the exported document',
    () async {
      final document = SessionArtifactExporter.document(
        const SessionArtifact(
          id: 'script',
          type: SessionArtifactType.script,
          title: '分镜',
          summary: '简介',
          metadata: '',
          shots: [SessionArtifactShot('镜头 1', '00:00', '画面', '旁白')],
        ),
      );
      expect(
        await document.file.readAsString(),
        '简介\n\n## 镜头 1\n\n00:00\n\n画面\n\n旁白',
      );
    },
  );

  test(
    'desktop saves UTF-8 to the selected path and cancellation writes nothing',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final directory = await Directory.systemTemp.createTemp(
        'popi-text-save-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      String? savePath;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getSavePath');
        expect((call.arguments as Map)['suggestedName'], '选题：测试_环境_.md');
        return savePath;
      });
      expect(
        await SessionArtifactExporter.save(item, sharePositionOrigin: origin),
        isFalse,
      );
      expect(directory.listSync(), isEmpty);
      savePath = '${directory.path}/document.md';
      expect(
        await SessionArtifactExporter.save(item, sharePositionOrigin: origin),
        isTrue,
      );
      expect(await File(savePath).readAsString(), item.summary);
      savePath = '${directory.path}/missing/document.md';
      await expectLater(
        SessionArtifactExporter.save(item, sharePositionOrigin: origin),
        throwsA(isA<FileSystemException>()),
      );
      savePath = '${directory.path}/document.md';
      expect(
        await SessionArtifactExporter.save(item, sharePositionOrigin: origin),
        isTrue,
      );
    },
  );
}
