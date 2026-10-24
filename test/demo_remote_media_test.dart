import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_remote_media.dart';

const _remoteImage = DemoAsset(
  id: 'remote-image',
  title: 'Remote image',
  kind: DemoAssetKind.image,
  cover: 'https://harness.test/api_agent/v2/assets/remote-image/content',
  contentUrl: 'https://harness.test/api_agent/v2/assets/remote-image/content',
  mimeType: 'image/png',
  width: 4096,
  height: 4096,
);

void main() {
  test(
    'remote card and image-stack thumbnails request bounded decode widths',
    () {
      const headers = {
        'Cookie': '__Host-popi-test=private-session',
        'Origin': 'https://harness.test',
      };
      const cacheKey = 'remote-image::11111111-1111-4111-8111-111111111111';
      var unauthorized = 0;

      for (final width in [162, 900]) {
        final thumbnail = demoAssetImageProvider(
          _remoteImage,
          headers: headers,
          cacheKey: cacheKey,
          onUnauthorized: () => unauthorized++,
          cacheWidth: width,
        );

        expect(thumbnail, isA<ResizeImage>());
        final resized = thumbnail as ResizeImage;
        expect(resized.width, width);
        expect(resized.height, isNull);
        expect(resized.imageProvider, isA<CachedNetworkImageProvider>());
        final network = resized.imageProvider as CachedNetworkImageProvider;
        expect(network.url, _remoteImage.contentUrl);
        expect(network.headers, headers);
        expect(network.cacheKey, cacheKey);
        expect(network.cacheKey, isNot(contains(headers['Cookie']!)));
      }

      expect(unauthorized, 0);
    },
  );

  test('full-size remote preview keeps the original image provider', () {
    const headers = {
      'Cookie': '__Host-popi-test=private-session',
      'Origin': 'https://harness.test',
    };
    const cacheKey = 'remote-image::22222222-2222-4222-8222-222222222222';

    final preview = demoAssetImageProvider(
      _remoteImage,
      headers: headers,
      cacheKey: cacheKey,
      onUnauthorized: () {},
    );

    expect(preview, isA<CachedNetworkImageProvider>());
    final network = preview as CachedNetworkImageProvider;
    expect(network.url, _remoteImage.contentUrl);
    expect(network.headers, headers);
    expect(network.cacheKey, cacheKey);
  });
}
