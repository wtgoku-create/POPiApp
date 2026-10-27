import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/demo_upload_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Dio dio;
  late _Storage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage(await SharedPreferences.getInstance());
    storage.values[DemoRepository.harnessStorageKey] = jsonEncode({
      'sessions': <Object?>[],
      'assets': <Object?>[],
    });
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
  });

  tearDown(() => dio.close(force: true));

  test('NetworkAgentApi sends raw bytes and the fixed upload query', () async {
    final adapter = _UploadAdapter();
    dio.httpClientAdapter = adapter;
    final bytes = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);

    await NetworkAgentApi(dio).uploadAsset(
      clientRequestId: 'fixed-request',
      name: '南极.png',
      mimeType: 'image/png',
      bytes: bytes,
    );

    expect(adapter.options!.path, '/api_agent/v2/assets');
    expect(adapter.options!.queryParameters, {
      'clientRequestId': 'fixed-request',
      'name': '南极.png',
    });
    expect(adapter.options!.contentType, 'image/png');
    expect(adapter.body, bytes);
  });

  test(
    'retry after persistence failure does not repeat successful POST',
    () async {
      final api = _UploadApi(dio);
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      final bytes = _pngBytes();
      final file = DemoUploadFile(
        clientRequestId: 'stable-request',
        name: '南极.png',
        mimeType: 'image/png',
        sizeBytes: bytes.length,
        kind: DemoAssetKind.image,
        readBytes: () async => bytes,
      );

      storage.failWrites = true;
      await expectLater(repository.uploadFile(file), throwsStateError);
      expect(api.uploadCalls, 1);
      storage.failWrites = false;

      final asset = await repository.uploadFile(file);
      expect(api.uploadCalls, 1);
      expect(asset.id, 'upload-1');
      expect(repository.assets.single.id, 'upload-1');

      await repository.refreshAssets();
      expect(repository.assets.single.id, 'upload-1');
    },
  );

  test('global listing replaces uploads and keeps session assets', () async {
    storage.values[DemoRepository.harnessStorageKey] = jsonEncode({
      'sessions': <Object?>[],
      'assets':
          [
            _assetRecord('old-upload', kind: 'image', sessionId: null),
            _assetRecord('generated', kind: 'image', sessionId: 'session-1'),
          ].map((record) {
            final path = record['contentUrl']! as String;
            return {
              ...record,
              'cover': 'http://127.0.0.1:3084$path',
              'contentUrl': 'http://127.0.0.1:3084$path',
            };
          }).toList(),
    });
    final api = _UploadApi(dio)
      ..listed = [
        _assetRecord('new-upload', kind: 'audio', sessionId: null),
        _assetRecord('generated', kind: 'image', sessionId: 'session-1'),
      ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.refreshAssets();

    expect(repository.assets.map((asset) => asset.id).toList(), [
      'new-upload',
      'generated',
    ]);
    final audio = repository.assets.first;
    expect(audio.kind, DemoAssetKind.audio);
    expect(audio.media, audio.contentUrl);
  });

  test('a delayed older global listing cannot replace a newer one', () async {
    final first = Completer<Map<String, dynamic>>();
    final second = Completer<Map<String, dynamic>>();
    final api = _UploadApi(dio)..assetResponses.addAll([first, second]);
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    final olderRefresh = repository.refreshAssets();
    final newerRefresh = repository.refreshAssets();
    second.complete({
      'list': [_assetRecord('new-upload', kind: 'image', sessionId: null)],
    });
    await newerRefresh;
    first.complete({
      'list': [_assetRecord('old-upload', kind: 'image', sessionId: null)],
    });
    await olderRefresh;

    expect(repository.assets.map((asset) => asset.id), ['new-upload']);
  });

  test('remote script is restored and decoded lazily', () async {
    final body = Uint8List.fromList(utf8.encode('# 南极\n脚本'));
    final api = _UploadApi(dio)
      ..readBodies['script-1'] = body
      ..listed = [
        _assetRecord(
          'script-1',
          kind: 'script',
          sessionId: null,
          sizeBytes: body.length,
        ),
      ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.refreshAssets();
    final asset = repository.assets.single;
    expect(asset.body, isEmpty);
    expect(await repository.readAssetText(asset), '# 南极\n脚本');
    expect(api.readCalls, 1);

    final restored = DemoRepository.harness(storage, api)..restore();
    addTearDown(restored.dispose);
    expect(restored.assets.single.kind, DemoAssetKind.script);
    expect(restored.assets.single.contentUrl, asset.contentUrl);
  });

  test(
    'read refuses an asset URL outside the configured Agent origin',
    () async {
      await expectLater(
        NetworkAgentApi(dio).readAssetBytes(
          'https://attacker.invalid/api_agent/v2/assets/asset-1/content',
        ),
        throwsFormatException,
      );
    },
  );

  test('NetworkAgentApi reads bytes from its owned content route', () async {
    final adapter = _UploadAdapter();
    dio.httpClientAdapter = adapter;

    final bytes = await NetworkAgentApi(
      dio,
    ).readAssetBytes('/api_agent/v2/assets/upload-1/content');

    expect(bytes, _pngBytes());
    expect(
      adapter.options!.uri.toString(),
      'http://127.0.0.1:3084/api_agent/v2/assets/upload-1/content',
    );
  });
}

class _Storage extends PreferencesStorage {
  _Storage(super.preferences);

  final values = <String, String>{};
  bool failWrites = false;

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('Disk unavailable');
    values[key] = value;
  }
}

class _UploadApi extends NetworkAgentApi {
  _UploadApi(super.dio);

  int uploadCalls = 0;
  int readCalls = 0;
  List<Map<String, Object?>> listed = [];
  final Map<String, Uint8List> readBodies = {};
  final List<Completer<Map<String, dynamic>>> assetResponses = [];

  @override
  Future<Map<String, dynamic>> uploadAsset({
    required String clientRequestId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    CancelToken? cancelToken,
  }) async {
    uploadCalls += 1;
    return {
      'asset': _assetRecord(
        'upload-1',
        kind: 'image',
        sessionId: null,
        sizeBytes: bytes.length,
      ),
    };
  }

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => assetResponses.isEmpty
      ? {'list': listed}
      : assetResponses.removeAt(0).future;

  @override
  Future<Uint8List> readAssetBytes(
    String contentUrl, {
    CancelToken? cancelToken,
  }) async {
    readCalls += 1;
    final id = Uri.parse(contentUrl).pathSegments.reversed.elementAt(1);
    return readBodies[id]!;
  }
}

class _UploadAdapter implements HttpClientAdapter {
  RequestOptions? options;
  Uint8List body = Uint8List(0);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    if (options.method == 'GET') {
      return ResponseBody.fromBytes(
        _pngBytes(),
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
        },
      );
    }
    final chunks = await requestStream?.toList() ?? const <Uint8List>[];
    body = Uint8List.fromList(chunks.expand((chunk) => chunk).toList());
    return ResponseBody.fromString(
      jsonEncode({
        'asset': _assetRecord(
          'upload-1',
          kind: 'image',
          sessionId: null,
          sizeBytes: body.length,
        ),
      }),
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Uint8List _pngBytes() =>
    Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

Map<String, Object?> _assetRecord(
  String id, {
  required String kind,
  required String? sessionId,
  int sizeBytes = 8,
}) {
  final mimeType = switch (kind) {
    'image' => 'image/png',
    'video' => 'video/mp4',
    'audio' => 'audio/mpeg',
    'script' => 'text/markdown',
    _ => throw ArgumentError.value(kind),
  };
  return {
    'id': id,
    'title':
        '$id.${kind == 'script'
            ? 'md'
            : kind == 'audio'
            ? 'mp3'
            : 'png'}',
    'kind': kind,
    'sessionId': sessionId,
    'mimeType': mimeType,
    'sha256': 'hash-$id',
    'sizeBytes': sizeBytes,
    'width': kind == 'image' ? 32 : 0,
    'height': kind == 'image' ? 32 : 0,
    'contentUrl': '/api_agent/v2/assets/$id/content',
  };
}
