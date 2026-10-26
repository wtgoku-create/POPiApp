import '../domain/demo_models.dart';

/// Curated public characters imported from https://www.popi.art/characters.
///
/// The bundled image is used for fast/offline catalog rendering. The original
/// public three-view image remains in [DemoRoleProfile.referenceImageUrls] so
/// the selected character can be supplied as generation context.
abstract final class DemoWebsiteCharacterCatalog {
  static const legacyProfiles = <String, DemoRoleProfile>{
    'alice': DemoRoleProfile(
      name: '爱丽丝',
      instructions:
          '性格：外在张扬直率，内心敏感，重视真挚的友情。\n'
          '外观：棕色及肩短发、两枚红色蝴蝶结发夹，白色短袖上衣配黄色衣领；角色比例和配色以公开参考三视图为准。\n'
          '参考图的多视角和表情均属于爱丽丝同一角色；生成时以用户要求的人物数量为准，不将多视图当作多个人物。',
      revision: 'popi-art-651-af1b8f4b9b25',
      referenceImageUrls: [
        'https://static.popi.art/media/2026/0713/139187.png',
      ],
    ),
  };

  static const legacyAvatarAssets = <String, String>{
    'alice': 'assets/images/demo_role_1.png',
  };

  static const characters = [
    DemoCharacter(
      'popi-character-1058',
      '豆豆',
      'assets/images/popi_character_1058.png',
    ),
    DemoCharacter(
      'popi-character-655',
      '康欣',
      'assets/images/popi_character_655.png',
    ),
    DemoCharacter(
      'popi-character-653',
      'L智',
      'assets/images/popi_character_653.png',
    ),
  ];

  static const profiles = <String, DemoRoleProfile>{
    'popi-character-1058': DemoRoleProfile(
      name: '豆豆',
      instructions:
          '性格：活泼开朗，乐于帮助他人，保持少女心。\n'
          '外观：以公开参考三视图为准，创作时保持角色比例、服饰和配色一致。\n'
          '参考图的多视角和表情均属于豆豆同一角色；生成时以用户要求的人物数量为准，不将多视图当作多个人物。',
      revision: 'popi-art-1058-b218bd16ebd9',
      referenceImageUrls: [
        'https://static.popi.art/media/2026/0924/282014.png',
      ],
    ),
    'popi-character-655': DemoRoleProfile(
      name: '康欣',
      instructions:
          '性格：表情外露的气氛担当，心思单纯敏感。开心时咧嘴大笑，难过时掉眼泪，生气时鼓脸炸毛。\n'
          '外观：头顶常驻软萌小团子；其余比例、服饰和配色以公开参考三视图为准。\n'
          '参考图的多视角和表情均属于康欣同一角色；生成时以用户要求的人物数量为准，不将多视图当作多个人物。',
      revision: 'popi-art-655-24de393f591b',
      referenceImageUrls: [
        'https://static.popi.art/media/2026/0713/139225.png',
      ],
    ),
    'popi-character-653': DemoRoleProfile(
      name: 'L智',
      instructions:
          '性格：搞怪、帅气、活泼，表情灵动多变，爱举墨镜比耶。\n'
          '外观：黑帽、绿T、波点短裤、白鞋；比例和配色以公开参考三视图为准。\n'
          '参考图的多视角和表情均属于L智同一角色；生成时以用户要求的人物数量为准，不将多视图当作多个人物。',
      revision: 'popi-art-653-7171d9336ad4',
      referenceImageUrls: [
        'https://static.popi.art/media/2026/0713/139222.png',
      ],
    ),
  };

  static DemoRoleProfile? profile(String roleId) =>
      profiles[roleId] ?? legacyProfiles[roleId];

  static String? bundledAvatar(String roleId) =>
      characters
          .where((character) => character.id == roleId)
          .firstOrNull
          ?.image ??
      legacyAvatarAssets[roleId];
}
