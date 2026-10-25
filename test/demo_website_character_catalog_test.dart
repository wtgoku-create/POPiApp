import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/demo/data/demo_fixtures.dart';
import 'package:popi_ai_app/features/demo/data/demo_website_character_catalog.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';

void main() {
  test(
    'website catalog contains three complete, uniquely namespaced profiles',
    () {
      const ids = {
        'popi-character-1058',
        'popi-character-655',
        'popi-character-653',
      };
      expect(
        DemoWebsiteCharacterCatalog.characters.map((value) => value.id).toSet(),
        ids,
      );
      expect(DemoWebsiteCharacterCatalog.profiles.keys.toSet(), ids);
      expect(
        DemoWebsiteCharacterCatalog.characters
            .map((value) => value.name)
            .toSet(),
        {'豆豆', '康欣', 'L智'},
      );
      for (final character in DemoWebsiteCharacterCatalog.characters) {
        final profile = DemoWebsiteCharacterCatalog.profile(character.id)!;
        expect(profile.name, character.name);
        expect(profile.instructions, isNotEmpty);
        expect(profile.revision, startsWith('popi-art-'));
        expect(profile.referenceImageUrls, hasLength(1));
        expect(
          Uri.parse(profile.referenceImageUrls.single).host,
          'static.popi.art',
        );
        expect(profile.isReady, isTrue);
        expect(character.image, startsWith('assets/images/popi_character_'));
      }
    },
  );

  test('existing bundled role identities remain available and unchanged', () {
    expect(
      DemoFixtures.characters.where((role) => role.id == 'alice').single.name,
      '爱丽丝',
    );
    expect(
      DemoFixtures.characters.where((role) => role.id == 'hua').single.name,
      '花西冷少',
    );
    expect(
      DemoFixtures.characters.map((role) => role.id).toSet().length,
      DemoFixtures.characters.length,
    );
    const importedIds = {
      'popi-character-1058',
      'popi-character-655',
      'popi-character-653',
    };
    for (final session in DemoFixtures.sessions()) {
      expect(session.roles.any(importedIds.contains), isFalse);
    }
  });

  test(
    'legacy Alice keeps its stable ID and gains the verified website profile',
    () {
      final alice = DemoWebsiteCharacterCatalog.profile('alice')!;
      expect(alice.name, '爱丽丝');
      expect(alice.revision, 'popi-art-651-af1b8f4b9b25');
      expect(alice.instructions, contains('外在张扬直率'));
      expect(alice.instructions, contains('不将多视图当作多个人物'));
      expect(alice.referenceImageUrls, [
        'https://static.popi.art/media/2026/0713/139187.png',
      ]);
      expect(
        DemoWebsiteCharacterCatalog.bundledAvatar('alice'),
        'assets/images/demo_role_1.png',
      );
      expect(
        DemoWebsiteCharacterCatalog.characters.where(
          (role) => role.id == 'alice',
        ),
        isEmpty,
      );
      expect(
        DemoFixtures.characters.where((role) => role.id == 'alice'),
        hasLength(1),
      );
    },
  );

  test('selected website profile survives the session cache contract', () {
    final source = DemoWebsiteCharacterCatalog.profile('popi-character-1058')!;
    final session = DemoSession(
      id: 'website-character',
      title: '网站角色上下文',
      kind: DemoSessionKind.conversation,
      members: const ['popi'],
      roles: const ['popi-character-1058'],
      messages: const [],
      roleProfiles: {'popi-character-1058': source},
    );
    final restored = DemoSession.fromJson(session.toJson());
    expect(
      restored.roleProfiles['popi-character-1058']?.toJson(),
      source.toJson(),
    );
    expect(restored.roleProfiles['popi-character-1058']?.isReady, isTrue);
    expect(restored.members, ['popi']);
  });
}
