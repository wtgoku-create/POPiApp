import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_file_picker.dart';
import 'package:popi_ai_app/features/demo/data/demo_media_exporter.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/demo_upload_file.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_controller.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _documents = <(String, String, List<int>)>[
  ('pdf', 'application/pdf', [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37]),
  (
    'doc',
    'application/msword',
    [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
  ),
  (
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    [0x50, 0x4B, 0x03, 0x04],
  ),
  (
    'ppt',
    'application/vnd.ms-powerpoint',
    [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
  ),
  (
    'pptx',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    [0x50, 0x4B, 0x03, 0x04],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all PDF and Office picker types retain original MIME and use the script family',
    () async {
      for (final (extension, mime, signature) in _documents) {
        final bytes = Uint8List.fromList(signature);
        final files = await demoUploadFilesFromXFiles([
          XFile.fromData(bytes, name: '材料.$extension', path: '材料.$extension'),
        ]);
        expect(files.single.mimeType, mime);
        expect(files.single.kind, DemoAssetKind.script);
        expect(await files.single.readBytes(), bytes);
        final direct = DemoUploadFile.fromBytes(
          name: '材料.$extension',
          mimeType: mime,
          bytes: bytes,
        );
        expect(direct.clientRequestId, files.single.clientRequestId);
      }
    },
  );

  test(
    'document and text limits remain separate with signatures checked before upload',
    () async {
      for (final (extension, mime, _) in _documents) {
        DemoUploadFile.validateMetadata(
          name: 'file.$extension',
          mimeType: mime,
          sizeBytes: 20 * 1024 * 1024,
          kind: DemoAssetKind.script,
        );
        expect(
          () => DemoUploadFile.validateMetadata(
            name: 'file.$extension',
            mimeType: mime,
            sizeBytes: 20 * 1024 * 1024 + 1,
            kind: DemoAssetKind.script,
          ),
          throwsA(
            isA<DemoUploadException>().having(
              (e) => e.code,
              'code',
              'FILE_TOO_LARGE',
            ),
          ),
        );
        expect(
          () => DemoUploadFile.fromBytes(
            name: 'fake.$extension',
            mimeType: mime,
            bytes: Uint8List.fromList(utf8.encode('ordinary text')),
          ),
          throwsA(
            isA<DemoUploadException>().having(
              (e) => e.code,
              'code',
              'INVALID_CONTENT',
            ),
          ),
        );
        expect(
          DemoUploadFile.limitFor(DemoAssetKind.script, mimeType: mime),
          20 * 1024 * 1024,
        );
      }
      expect(
        () => DemoUploadFile.validateMetadata(
          name: 'text.txt',
          mimeType: 'text/plain',
          sizeBytes: 2 * 1024 * 1024 + 1,
          kind: DemoAssetKind.script,
        ),
        throwsA(
          isA<DemoUploadException>().having(
            (e) => e.code,
            'code',
            'FILE_TOO_LARGE',
          ),
        ),
      );
    },
  );

  test(
    'clipboard byte files own their data and share the picker request identity',
    () async {
      final bytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      final file = DemoUploadFile.fromBytes(
        name: 'clipboard.png',
        mimeType: 'image/png',
        bytes: bytes,
      );
      final original = Uint8List.fromList(bytes);
      bytes[0] = 0;
      expect(await file.readBytes(), original);
      final firstRead = await file.readBytes();
      firstRead[0] = 0;
      expect(await file.readBytes(), original);
      expect(file.kind, DemoAssetKind.image);
      expect(
        () => DemoUploadFile.fromBytes(
          name: 'clipboard.svg',
          mimeType: 'image/svg+xml',
          bytes: original,
        ),
        throwsA(
          isA<DemoUploadException>().having(
            (e) => e.code,
            'code',
            'UNSUPPORTED_TYPE',
          ),
        ),
      );
    },
  );

  test(
    'message count, total bytes, and image subset budgets are independently bounded',
    () {
      DemoAsset asset(String id, int bytes, {bool image = false}) => DemoAsset(
        id: id,
        title: id,
        kind: image ? DemoAssetKind.image : DemoAssetKind.script,
        cover: '',
        sizeBytes: bytes,
        mimeType: image ? 'image/png' : 'application/pdf',
      );
      DemoUploadFile.validateMessageAttachments([
        for (var i = 0; i < 10; i++) asset('$i', 1),
      ]);
      expect(
        () => DemoUploadFile.validateMessageAttachments([
          for (var i = 0; i < 11; i++) asset('$i', 1),
        ]),
        throwsA(
          isA<DemoUploadException>().having(
            (e) => e.code,
            'code',
            'ATTACHMENT_LIMIT',
          ),
        ),
      );
      DemoUploadFile.validateMessageAttachments([
        asset('a', 20 * 1024 * 1024),
        asset('b', 20 * 1024 * 1024),
        asset('c', 10 * 1024 * 1024),
      ]);
      expect(
        () => DemoUploadFile.validateMessageAttachments([
          asset('a', 20 * 1024 * 1024),
          asset('b', 20 * 1024 * 1024),
          asset('c', 10 * 1024 * 1024 + 1),
        ]),
        throwsA(
          isA<DemoUploadException>().having(
            (e) => e.code,
            'code',
            'ATTACHMENTS_TOO_LARGE',
          ),
        ),
      );
      DemoUploadFile.validateMessageAttachments([
        asset('a', 10 * 1024 * 1024, image: true),
        asset('b', 10 * 1024 * 1024, image: true),
      ]);
      expect(
        () => DemoUploadFile.validateMessageAttachments([
          asset('a', 10 * 1024 * 1024, image: true),
          asset('b', 10 * 1024 * 1024 + 1, image: true),
        ]),
        throwsA(
          isA<DemoUploadException>().having(
            (e) => e.code,
            'code',
            'ATTACHMENTS_TOO_LARGE',
          ),
        ),
      );
    },
  );

  test(
    'document metadata restores while preview reads text endpoint and downloads original binary',
    () async {
      SharedPreferences.setMockInitialValues({
        DemoRepository.harnessStorageKey: '{"sessions":[],"assets":[]}',
      });
      final storage = PreferencesStorage(await SharedPreferences.getInstance());
      final dio = Dio(BaseOptions(baseUrl: 'https://agent.example'));
      addTearDown(() => dio.close(force: true));
      final api = _DocumentApi(dio);
      final repo = DemoRepository.harness(storage, api)..restore();
      addTearDown(repo.dispose);
      final bytes = Uint8List.fromList(_documents.first.$3);
      final asset = await repo.uploadFile(
        DemoUploadFile.fromBytes(
          name: '报告.pdf',
          mimeType: 'application/pdf',
          bytes: bytes,
        ),
      );
      expect(asset.isDocument, isTrue);
      expect(asset.document?.format, 'pdf');
      expect(asset.document?.pageCount, 3);
      expect(asset.document?.ocrUsed, isTrue);
      expect(asset.mimeType, 'application/pdf');
      expect(asset.body, isEmpty);
      expect(await repo.readAssetText(asset), '第一章\n服务端提取的正文');
      expect(api.textCalls, 1);
      expect(api.binaryCalls, 0);
      expect(await repo.readAssetBytes(asset), bytes);
      expect(api.binaryCalls, 1);
      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(restored.assets.single.document?.pageCount, 3);
      expect(restored.assets.single.document?.textCharacters, 13);
      expect(restored.assets.single.document?.truncated, isTrue);
      expect(
        restored.assets.single.copyWith(title: '改名.pdf').document?.ocrUsed,
        isTrue,
      );
      expect(restored.assets.single.contentUrl, asset.contentUrl);
    },
  );

  test(
    'upload timeout covers bounded parser deadline without changing ordinary request deadlines',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://agent.example',
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      addTearDown(() => dio.close(force: true));
      final captured = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            captured.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 201,
                data: request.path.endsWith('/text')
                    ? <String, dynamic>{'text': '正文'}
                    : <String, dynamic>{'asset': <String, Object?>{}},
              ),
            );
          },
        ),
      );
      final api = NetworkAgentApi(dio);
      await api.uploadAsset(
        clientRequestId: 'request',
        name: '报告.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList(_documents.first.$3),
      );
      expect(captured.single.sendTimeout, const Duration(seconds: 200));
      expect(captured.single.receiveTimeout, const Duration(seconds: 200));
      await api.assetText('doc-1');
      expect(captured.last.path, '/api_agent/v2/assets/doc-1/text');
      expect(captured.last.receiveTimeout, const Duration(seconds: 15));
    },
  );

  test(
    'a parsed document can be sent without text through the owned attachment contract',
    () async {
      const session = DemoSession(
        id: 's1',
        title: 'POPi',
        kind: DemoSessionKind.conversation,
        members: ['popi'],
        roles: [],
        messages: [],
        memberNames: {'popi': 'POPi'},
        configurationStatus: 'configured',
        configRevision: 1,
      );
      SharedPreferences.setMockInitialValues({
        DemoRepository.harnessStorageKey: jsonEncode({
          'sessions': [session.toJson()],
          'assets': [],
        }),
      });
      final storage = PreferencesStorage(await SharedPreferences.getInstance());
      final dio = Dio(BaseOptions(baseUrl: 'https://agent.example'));
      addTearDown(() => dio.close(force: true));
      final api = _DocumentApi(dio);
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 0,
      )..restore();
      addTearDown(repository.dispose);
      final asset = await repository.uploadFile(
        DemoUploadFile.fromBytes(
          name: '报告.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(_documents.first.$3),
        ),
      );
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(await controller.send('', [asset.id], l), isTrue);
      expect(api.sentText, '');
      expect(api.sentMediaIds, ['doc-1']);
      expect(api.sentSkillInvocation, isNull);
      expect(api.textCalls, 0); // DSH resolves its own verified text sidecar.
    },
  );

  test(
    'original PDF and Office exports keep bytes, extension and MIME without duplicated suffixes',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final shares = <ShareParams>[];
      DemoMediaExporter.debugShare = (params) async => shares.add(params);
      addTearDown(() => DemoMediaExporter.debugShare = null);
      for (final (extension, mime, signature) in _documents) {
        final bytes = Uint8List.fromList(signature);
        final asset = DemoAsset(
          id: extension,
          title: '报告.$extension',
          kind: DemoAssetKind.script,
          cover: '',
          mimeType: mime,
          contentUrl:
              'https://agent.example/api_agent/v2/assets/$extension/content',
          sizeBytes: bytes.length,
        );
        expect(DemoMediaExporter.displayExtension(asset), extension);
        await DemoMediaExporter.save(
          asset,
          const Rect.fromLTWH(0, 0, 1, 1),
          readBytes: () async => bytes,
        );
        final shared = shares.removeAt(0);
        expect(shared.fileNameOverrides, ['报告.$extension']);
        expect(shared.files!.single.mimeType, mime);
        expect(await shared.files!.single.readAsBytes(), bytes);
      }
    },
  );
}

class _DocumentApi extends NetworkAgentApi {
  _DocumentApi(super.dio);
  int textCalls = 0, binaryCalls = 0;
  String? sentText;
  List<String>? sentMediaIds;
  Map<String, Object?>? sentSkillInvocation;
  @override
  Future<Map<String, dynamic>> uploadAsset({
    required String clientRequestId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    CancelToken? cancelToken,
  }) async => {
    'asset': {
      'id': 'doc-1',
      'title': name,
      'kind': 'script',
      'mimeType': mimeType,
      'sizeBytes': bytes.length,
      'contentUrl': '/api_agent/v2/assets/doc-1/content',
      'document': {
        'format': 'pdf',
        'status': 'ready',
        'pageCount': 3,
        'textCharacters': 13,
        'truncated': true,
        'ocrUsed': true,
      },
    },
  };
  @override
  Future<Map<String, dynamic>> assetText(
    String assetId, {
    CancelToken? cancelToken,
  }) async {
    textCalls++;
    return {
      'text': '第一章\n服务端提取的正文',
      'document': {'format': 'pdf', 'status': 'ready'},
    };
  }

  @override
  Future<Uint8List> readAssetBytes(
    String contentUrl, {
    CancelToken? cancelToken,
  }) async {
    binaryCalls++;
    return Uint8List.fromList(_documents.first.$3);
  }

  @override
  Future<Map<String, dynamic>> sendSessionMessage(
    String id, {
    required String clientRequestId,
    required String text,
    String? taskId,
    List<String>? mediaIds,
    List<String>? contextRoleIds,
    Map<String, Object?>? skillInvocation,
    CancelToken? cancelToken,
  }) async {
    sentText = text;
    sentMediaIds = mediaIds;
    sentSkillInvocation = skillInvocation;
    return {'runId': 'run-1', 'state': 'completed'};
  }

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => {
    'session': {
      'id': id,
      'title': 'POPi',
      'kind': 'conversation',
      'configurationStatus': 'configured',
      'configRevision': 1,
      'configuration': {
        'members': ['popi'],
        'roles': [],
        'memberNames': {'popi': 'POPi'},
        'capabilities': DemoSession.defaultCapabilities,
        'activeMemberId': 'popi',
        'workMode': 'manual',
      },
    },
    'messages': <Object?>[],
    'runs': [
      {'id': 'run-1', 'state': 'completed'},
    ],
    'mediaJobs': <Object?>[],
    'filmJobs': <Object?>[],
  };
}
