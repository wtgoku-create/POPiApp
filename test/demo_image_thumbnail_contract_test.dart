import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/harness_access_session.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _origin = 'https://harness.test';
const _assetId = 'image-1';
const _contentPath = '/api_agent/v2/assets/$_assetId/content';
const _thumbnailPath = '/api_agent/v2/assets/$_assetId/thumbnail';

void main() {
  late Dio dio;
  late PreferencesStorage storage;
  late _ThumbnailApi api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio(BaseOptions(baseUrl: _origin));
    api = _ThumbnailApi(dio);
  });

  tearDown(() => dio.close(force: true));

  test('thumbnail survives JSON, title copy, and legacy JSON', () {
    const asset = DemoAsset(
      id: _assetId,
      title: '南极角色图',
      kind: DemoAssetKind.image,
      cover: '$_origin$_contentPath',
      contentUrl: '$_origin$_contentPath',
      thumbnailUrl: '$_origin$_thumbnailPath',
    );

    final restored = DemoAsset.fromJson(asset.toJson());
    expect(restored.thumbnailUrl, asset.thumbnailUrl);
    expect(asset.copyWith(title: '瓦特').thumbnailUrl, asset.thumbnailUrl);

    final legacy = Map<String, Object?>.from(asset.toJson())
      ..remove('thumbnailUrl');
    expect(DemoAsset.fromJson(legacy).thumbnailUrl, isEmpty);
  });

  test('thumbnail resolver accepts only the exact relative owned route', () {
    expect(
      api.resolveAssetThumbnailUrl(_thumbnailPath),
      '$_origin$_thumbnailPath',
    );

    for (final invalid in [
      '$_origin$_thumbnailPath',
      '//foreign.test$_thumbnailPath',
      '$_thumbnailPath?size=320',
      '$_thumbnailPath#preview',
      _contentPath,
      '/api_agent/v2/assets/image%2F1/thumbnail',
      '/api_agent/v2/assets/image.1/thumbnail',
    ]) {
      expect(
        () => api.resolveAssetThumbnailUrl(invalid),
        throwsFormatException,
        reason: invalid,
      );
    }
  });

  test('same-origin thumbnail auth and cache partition stay session-bound', () {
    final session = _session();
    const url = '$_origin$_thumbnailPath';

    final headers = harnessAccessHeadersFor(
      url,
      session: session,
      baseUrl: _origin,
      now: _now,
    );
    final cacheKey = harnessAccessCacheKeyFor(
      url,
      session: session,
      baseUrl: _origin,
      now: _now,
    );

    expect(headers, {
      'Cookie': '${HarnessAccessSession.cookieName}=private-cookie',
      'Origin': _origin,
    });
    expect(cacheKey, '$url::${session.cacheNamespace}');
    expect(cacheKey, isNot(contains(session.cookieValue)));
  });

  test('foreign and ambiguous thumbnail URLs receive no access', () {
    final session = _session();
    for (final url in [
      'https://foreign.test$_thumbnailPath',
      'http://harness.test$_thumbnailPath',
      '$_origin.evil$_thumbnailPath',
    ]) {
      expect(
        harnessAccessHeadersFor(
          url,
          session: session,
          baseUrl: _origin,
          now: _now,
        ),
        isEmpty,
      );
      expect(
        harnessAccessCacheKeyFor(
          url,
          session: session,
          baseUrl: _origin,
          now: _now,
        ),
        isNull,
      );
    }
    expect(
      harnessAccessCacheKeyFor(
        '$_origin$_thumbnailPath?size=320',
        session: session,
        baseUrl: _origin,
        now: _now,
      ),
      isNull,
    );
  });

  test(
    'repository accepts a matching image thumbnail and preserves content',
    () async {
      api.records = [_imageRecord(thumbnailUrl: _thumbnailPath)];
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);

      await repository.refreshAssets();

      final asset = repository.assets.single;
      expect(asset.contentUrl, '$_origin$_contentPath');
      expect(asset.cover, asset.contentUrl);
      expect(asset.thumbnailUrl, '$_origin$_thumbnailPath');
    },
  );

  test('repository ignores wrong-id, foreign, and query thumbnails', () async {
    for (final invalid in [
      '/api_agent/v2/assets/other-id/thumbnail',
      'https://foreign.test$_thumbnailPath',
      '$_thumbnailPath?size=320',
    ]) {
      api.records = [_imageRecord(thumbnailUrl: invalid)];
      final repository = DemoRepository.harness(storage, api)..restore();

      await repository.refreshAssets();

      final asset = repository.assets.single;
      expect(asset.thumbnailUrl, isEmpty, reason: invalid);
      expect(asset.contentUrl, '$_origin$_contentPath');
      expect(asset.cover, asset.contentUrl);
      repository.dispose();
    }
  });

  test(
    'persisted same-origin thumbnail is restored without rewriting content',
    () async {
      api.records = [_imageRecord(thumbnailUrl: _thumbnailPath)];
      final first = DemoRepository.harness(storage, api)..restore();
      await first.refreshAssets();
      final original = first.assets.single;
      first.dispose();

      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);

      expect(restored.assets.single.thumbnailUrl, original.thumbnailUrl);
      expect(restored.assets.single.contentUrl, original.contentUrl);
    },
  );

  test('old server image without a thumbnail remains usable', () async {
    api.records = [_imageRecord()];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.refreshAssets();

    final asset = repository.assets.single;
    expect(asset.thumbnailUrl, isEmpty);
    expect(asset.contentUrl, '$_origin$_contentPath');
    expect(asset.cover, asset.contentUrl);
  });
}

HarnessAccessSession _session() => HarnessAccessSession(
  cookieValue: 'private-cookie',
  origin: _origin,
  expiresAt: _now().add(const Duration(hours: 1)),
  cacheNamespace: '11111111-1111-4111-8111-111111111111',
);

DateTime _now() => DateTime.utc(2026, 10, 25);

Map<String, Object?> _imageRecord({String? thumbnailUrl}) => {
  'id': _assetId,
  'title': '南极角色图.png',
  'kind': 'image',
  'mimeType': 'image/png',
  'sizeBytes': 128,
  'contentUrl': _contentPath,
  if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
  'width': 1024,
  'height': 1024,
  'createdAt': '2026-10-25T00:00:00.000Z',
};

class _ThumbnailApi extends NetworkAgentApi {
  _ThumbnailApi(super.dio);

  List<Map<String, Object?>> records = [];

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': records};
}
