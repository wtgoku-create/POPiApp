import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/data/demo_website_character_catalog.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_content_role_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DemoRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
  });

  tearDown(() => repository.dispose());

  test(
    'official Alice uses the stable bundled avatar instead of its sheet',
    () {
      final session = DemoSession(
        id: 'alice-avatar',
        title: 'Alice',
        kind: DemoSessionKind.conversation,
        members: const ['popi'],
        roles: const ['alice'],
        messages: const [],
        roleProfiles: {'alice': DemoWebsiteCharacterCatalog.profile('alice')!},
      );

      expect(
        demoContentRoleAvatarSource(repository, session, 'alice'),
        'assets/images/demo_role_1.png',
      );
    },
  );

  test('a saved custom Alice reference remains the visible avatar source', () {
    const customUrl = 'https://example.test/custom-alice.png';
    const session = DemoSession(
      id: 'custom-alice-avatar',
      title: 'Alice',
      kind: DemoSessionKind.conversation,
      members: ['popi'],
      roles: ['alice'],
      messages: [],
      roleProfiles: {
        'alice': DemoRoleProfile(
          name: '我的爱丽丝',
          instructions: '用户自定义',
          revision: 'user-revision',
          referenceImageUrls: [customUrl],
        ),
      },
    );

    expect(
      demoContentRoleAvatarSource(repository, session, 'alice'),
      customUrl,
    );
  });
}
