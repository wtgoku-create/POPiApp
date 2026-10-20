import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/data/session_artifact_exporter.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/session_artifact.dart';

import 'support/session_fixtures.dart';

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

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    test(
      'saves original video bytes on $platform and cleans up temporary files',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        const bytes = [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50];
        final requests = <Uri>[];
        server.listen((request) async {
          requests.add(request.uri);
          request.response.add(bytes);
          await request.response.close();
        });
        final directory = await Directory.systemTemp.createTemp(
          'popi-video-export-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const gallery = MethodChannel('gal');
        const selector = MethodChannel('plugins.flutter.io/file_selector');
        addTearDown(() => messenger.setMockMethodCallHandler(gallery, null));
        addTearDown(() => messenger.setMockMethodCallHandler(selector, null));
        String? temporaryPath;
        messenger.setMockMethodCallHandler(gallery, (call) async {
          if (call.method == 'hasAccess') return true;
          if (call.method == 'putVideo') {
            temporaryPath = (call.arguments as Map)['path'] as String;
            expect(await File(temporaryPath!).readAsBytes(), bytes);
          }
          return null;
        });
        messenger.setMockMethodCallHandler(selector, (call) async {
          expect((call.arguments as Map)['suggestedName'], '天台黄昏.mov');
          return '${directory.path}/saved.mov';
        });
        final repository = _MediaRepository(
          'http://127.0.0.1:${server.port}/original.mov?signature=test',
        );
        final video = SessionArtifact.fromJson({
          'id': 'media:video',
          'category': 'media',
          'type': 'video',
          'title': '天台黄昏',
          'media': {'id': 'video', 'kind': 'video'},
        });
        final saved = await HttpOverrides.runWithHttpOverrides(
          () => SessionArtifactExporter.save(
            video,
            repository: repository,
            sharePositionOrigin: origin,
          ),
          _LoopbackHttpOverrides(),
        );
        expect(saved, isTrue);
        expect(repository.requestedId, 'video');
        expect(requests.single.toString(), '/original.mov?signature=test');
        if (platform == TargetPlatform.macOS) {
          expect(
            await File('${directory.path}/saved.mov').readAsBytes(),
            bytes,
          );
        } else {
          expect(temporaryPath, isNotNull);
          expect(await File(temporaryPath!).parent.exists(), isFalse);
        }
      },
    );
  }
}

class _MediaRepository extends FixtureSessionRepository {
  _MediaRepository(this.url);
  final String url;
  String? requestedId;

  @override
  Future<ConversationMedia> media(String id, {CancelToken? cancelToken}) async {
    requestedId = id;
    return ConversationMedia(id: id, kind: 'video', url: url);
  }
}

class _LoopbackHttpOverrides extends HttpOverrides {}
