import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/demo_role_preview.dart';

void main() {
  group('DemoRolePreviewData', () {
    test(
      'preserves instructions and only reads explicit standalone labels',
      () {
        const instructions = '''
这个故事说她的性格：安静，但这不是标签行。
性格与表达风格： 克制、直接，保留停顿
目标受众: 初次租房的年轻人
Content tags: 合租, 职场
```
性格：不应读取
Target audience: also ignored
```
下一行是上一行的说明，不应被合并。''';
        const profile = DemoRoleProfile(
          name: '  星也  ',
          instructions: instructions,
          revision: 'opaque-revision-token',
        );

        final data = DemoRolePreviewData.fromProfile(
          roleId: 'seren',
          profile: profile,
          fallbackName: '备用名',
          assets: const [],
        );

        expect(data.name, profile.name);
        expect(data.instructions, same(instructions));
        expect(data.expressionStyle, '克制、直接，保留停顿');
        expect(data.targetAudience, '初次租房的年轻人');
        expect(data.contentTags, '合租, 职场');
        expect(data.isReady, isTrue);
      },
    );

    test(
      'leaves unavailable display facts empty and uses only the fallback name',
      () {
        final data = DemoRolePreviewData.fromProfile(
          roleId: 'empty',
          profile: null,
          fallbackName: '未命名角色',
          assets: const [],
        );

        expect(data.name, '未命名角色');
        expect(data.instructions, isEmpty);
        expect(data.expressionStyle, isEmpty);
        expect(data.targetAudience, isEmpty);
        expect(data.contentTags, isEmpty);
        expect(data.isReady, isFalse);
        expect(data.references, isEmpty);
        expect(data.missingReferenceCount, 0);
      },
    );

    test('does not turn an opaque revision into display data or readiness', () {
      final revisionOnly = DemoRolePreviewData.fromProfile(
        roleId: 'revision-only',
        profile: const DemoRoleProfile(
          name: '版本测试',
          revision: 'server-etag-not-a-version',
        ),
        fallbackName: '备用名',
        assets: const [],
      );
      final contextWithoutRevision = DemoRolePreviewData.fromProfile(
        roleId: 'missing-revision',
        profile: const DemoRoleProfile(instructions: '性格：沉稳'),
        fallbackName: '备用名',
        assets: const [],
      );

      expect(revisionOnly.isReady, isFalse);
      expect(revisionOnly.instructions, isEmpty);
      expect(revisionOnly.expressionStyle, isEmpty);
      expect(contextWithoutRevision.isReady, isFalse);
      expect(contextWithoutRevision.expressionStyle, '沉稳');
    });

    test('keeps owned references first, typed, deduplicated, and counted', () {
      const first = DemoAsset(
        id: 'image-a',
        title: '正面.png',
        kind: DemoAssetKind.image,
        cover: '/local/image-a.png',
        contentUrl: 'https://owned.test/image-a/content',
      );
      const second = DemoAsset(
        id: 'image-b',
        title: '侧面.png',
        kind: DemoAssetKind.image,
        cover: '/local/image-b.png',
        contentUrl: 'https://owned.test/image-b/content',
      );
      const video = DemoAsset(
        id: 'video-a',
        title: '动画.mp4',
        kind: DemoAssetKind.video,
        cover: '',
        contentUrl: 'https://owned.test/video-a/content',
      );
      const profile = DemoRoleProfile(
        revision: 'ready-context',
        referenceAssetIds: [
          'image-a',
          'image-a',
          'missing-image',
          'missing-image',
          'video-a',
        ],
        referenceImageUrls: [
          'https://public.test/reference.png',
          'https://owned.test/image-a/content',
          'https://owned.test/image-b/content',
          'https://public.test/reference.png',
          'file:///private/reference.png',
        ],
      );

      final data = DemoRolePreviewData.fromProfile(
        roleId: 'one-role',
        profile: profile,
        fallbackName: '单一角色',
        assets: const [first, second, video],
      );

      expect(data.isReady, isTrue);
      expect(data.missingReferenceCount, 2);
      expect(data.references, hasLength(3));
      expect(data.references.map((reference) => reference.key), [
        'one-role:asset:image-a',
        'one-role:asset:image-b',
        'one-role:url:https://public.test/reference.png',
      ]);
      expect(data.references[0].asset, same(first));
      expect(data.references[1].asset, same(second));
      expect(data.references[0].url, isNull);
      expect(data.references[1].url, isNull);
      expect(data.references[2].asset, isNull);
      expect(data.references[2].url, 'https://public.test/reference.png');
      expect(data.references.map((reference) => reference.isOwned), [
        true,
        true,
        false,
      ]);
      expect(data.references.map((reference) => reference.isPublic), [
        false,
        false,
        true,
      ]);
    });

    test('keeps multiple images under one role projection', () {
      const images = [
        DemoAsset(
          id: 'front',
          title: '正面',
          kind: DemoAssetKind.image,
          cover: 'front.png',
        ),
        DemoAsset(
          id: 'side',
          title: '侧面',
          kind: DemoAssetKind.image,
          cover: 'side.png',
        ),
        DemoAsset(
          id: 'back',
          title: '背面',
          kind: DemoAssetKind.image,
          cover: 'back.png',
        ),
      ];
      const profile = DemoRoleProfile(
        revision: 'context-1',
        referenceAssetIds: ['front', 'side', 'back'],
      );

      final role = DemoRolePreviewData.fromProfile(
        roleId: 'character-1',
        profile: profile,
        fallbackName: '角色 1',
        assets: images,
      );

      expect(role.references, hasLength(3));
      expect(
        role.references.map((reference) => reference.key),
        everyElement(startsWith('character-1:asset:')),
      );
    });
  });
}
