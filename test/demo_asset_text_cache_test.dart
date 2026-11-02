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

  test(
    'concurrent reads share one download and later reads use the cache',
    () async {
      final api = _TextApi(dio);
      final repository = _repository(storage, api);
      addTearDown(repository.dispose);
      final asset = _asset('shared', '# shared');
      final response = Completer<Uint8List>();
      api.readers[asset.contentUrl] = () => response.future;

      final first = repository.readAssetText(asset);
      final second = repository.readAssetText(asset);
      expect(api.readCalls, 1);

      response.complete(_bytes('# shared'));
      expect(await Future.wait([first, second]), ['# shared', '# shared']);
      expect(await repository.readAssetText(asset), '# shared');
      expect(api.readCalls, 1);
    },
  );

  test('assets with different IDs never share cached text', () async {
    final api = _TextApi(dio);
    final repository = _repository(storage, api);
    addTearDown(repository.dispose);
    final first = _asset('first', 'same', contentUrlId: 'shared');
    final second = _asset('second', 'same', contentUrlId: 'shared');
    api.readers[first.contentUrl] = () async => _bytes('same');

    expect(await repository.readAssetText(first), 'same');
    expect(await repository.readAssetText(second), 'same');
    expect(api.readCalls, 2);
  });

  test('changed asset identity metadata does not reuse cached text', () async {
    final api = _TextApi(dio);
    final repository = _repository(storage, api);
    addTearDown(repository.dispose);
    final first = _asset('asset', 'first', sha256: 'revision-1');
    final changed = _asset('asset', 'other', sha256: 'revision-2');
    var body = _bytes('first');
    api.readers[first.contentUrl] = () async => body;

    expect(await repository.readAssetText(first), 'first');
    body = _bytes('other');
    expect(await repository.readAssetText(changed), 'other');
    expect(api.readCalls, 2);
  });

  test('cache hits still validate the current asset title', () async {
    final api = _TextApi(dio);
    final repository = _repository(storage, api);
    addTearDown(repository.dispose);
    final asset = _asset('asset', 'cached');
    api.readers[asset.contentUrl] = () async => _bytes('cached');

    expect(await repository.readAssetText(asset), 'cached');
    await expectLater(
      repository.readAssetText(asset.copyWith(title: '../invalid.md')),
      throwsA(
        isA<DemoUploadException>().having(
          (error) => error.code,
          'code',
          'INVALID_NAME',
        ),
      ),
    );
    expect(api.readCalls, 1);
  });

  test('a failed download is not cached and can be retried', () async {
    final api = _TextApi(dio);
    final repository = _repository(storage, api);
    addTearDown(repository.dispose);
    final asset = _asset('retry', 'recovered');
    var attempt = 0;
    api.readers[asset.contentUrl] = () async {
      if (attempt++ == 0) throw StateError('temporary failure');
      return _bytes('recovered');
    };

    await expectLater(repository.readAssetText(asset), throwsStateError);
    expect(await repository.readAssetText(asset), 'recovered');
    expect(api.readCalls, 2);
  });

  test('least recently used entry is evicted at the entry limit', () async {
    final api = _TextApi(dio);
    final repository = _repository(storage, api);
    addTearDown(repository.dispose);
    final assets = [
      for (var index = 0; index < 17; index++)
        _asset('asset-$index', 'text-$index'),
    ];
    for (final asset in assets) {
      api.readers[asset.contentUrl] = () async => _bytes(asset.body);
      expect(await repository.readAssetText(asset), asset.body);
    }
    expect(api.readCalls, 17);

    expect(await repository.readAssetText(assets.first), assets.first.body);
    expect(api.readCalls, 18);
  });

  test('reset prevents a late download from repopulating the cache', () async {
    final api = _TextApi(dio);
    final repository = _repository(storage, api);
    addTearDown(repository.dispose);
    final asset = _asset('reset', 'after reset');
    final response = Completer<Uint8List>();
    api.readers[asset.contentUrl] = () => response.future;

    final pending = repository.readAssetText(asset);
    await repository.reset();
    response.complete(_bytes('after reset'));
    expect(await pending, 'after reset');

    api.readers[asset.contentUrl] = () async => _bytes('after reset');
    expect(await repository.readAssetText(asset), 'after reset');
    expect(api.readCalls, 2);
  });

  test(
    'dispose prevents a late download from repopulating the cache',
    () async {
      final api = _TextApi(dio);
      final repository = _repository(storage, api);
      final asset = _asset('disposed', 'after dispose');
      final response = Completer<Uint8List>();
      api.readers[asset.contentUrl] = () => response.future;

      final pending = repository.readAssetText(asset);
      repository.dispose();
      response.complete(_bytes('after dispose'));
      expect(await pending, 'after dispose');

      api.readers[asset.contentUrl] = () async => _bytes('after dispose');
      expect(await repository.readAssetText(asset), 'after dispose');
      expect(api.readCalls, 2);
    },
  );
}

DemoRepository _repository(_Storage storage, _TextApi api) =>
    DemoRepository.harness(storage, api)..restore();

DemoAsset _asset(
  String id,
  String text, {
  String? contentUrlId,
  String mimeType = 'text/markdown',
  String sha256 = 'same-hash',
}) => DemoAsset(
  id: id,
  title: '$id.md',
  kind: DemoAssetKind.script,
  cover: '',
  body: text,
  contentUrl:
      'http://127.0.0.1:3084/api_agent/v2/assets/${contentUrlId ?? id}/content',
  mimeType: mimeType,
  sha256: sha256,
  sizeBytes: _bytes(text).lengthInBytes,
);

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

class _Storage extends PreferencesStorage {
  _Storage(super.preferences);

  final values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _TextApi extends NetworkAgentApi {
  _TextApi(super.dio);

  int readCalls = 0;
  final Map<String, Future<Uint8List> Function()> readers = {};

  @override
  Future<Uint8List> readAssetBytes(
    String contentUrl, {
    CancelToken? cancelToken,
  }) {
    readCalls += 1;
    return readers[contentUrl]!();
  }
}
