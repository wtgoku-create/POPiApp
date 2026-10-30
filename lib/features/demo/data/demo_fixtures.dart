import '../domain/demo_models.dart';
import 'demo_website_character_catalog.dart';

/// Bundled design assets keep the entire demo usable without a backend.
abstract final class DemoFixtures {
  static const characters = [
    ...DemoWebsiteCharacterCatalog.characters,
    DemoCharacter('alice', '爱丽丝', 'assets/images/demo_role_1.png'),
    DemoCharacter('er', '尔尔', 'assets/images/demo_role_2.png'),
    DemoCharacter('hua', '花西冷少', 'assets/images/demo_role_3.png'),
    DemoCharacter('dou', '水濑兜兜儿', 'assets/images/demo_role_4.png'),
    DemoCharacter('qiqi', '奇奇蒂蒂', 'assets/images/demo_role_5.png'),
    DemoCharacter('fish', '人鱼小姐', 'assets/images/demo_role_6.png'),
    DemoCharacter('berry', '奇奇蒂蒂', 'assets/images/demo_role_7.png'),
    DemoCharacter('rain', '奇奇蒂蒂', 'assets/images/demo_role_8.png'),
    DemoCharacter('scarf', '人鱼小姐', 'assets/images/demo_role_9.png'),
    DemoCharacter('girl', '小夏', 'assets/images/demo_role_10.png'),
    DemoCharacter('ethan', 'Ethan', 'assets/images/demo_role_11.png'),
    DemoCharacter('leo', 'Leo', 'assets/images/demo_role_12.png'),
  ];
  static const memberImages = {
    'popi': 'assets/animations/bot_avatars/tiger.png',
    'designer': 'assets/animations/bot_avatars/rabbit.png',
    'writer': 'assets/animations/bot_avatars/monkey.png',
    'director': 'assets/animations/bot_avatars/dragon.png',
    'sound': 'assets/animations/bot_avatars/rooster.png',
  };

  static const _retiredMemberImages = {
    'assets/images/demo_avatar_popi.png': 'popi',
    'assets/images/demo_avatar_designer.png': 'designer',
    'assets/images/demo_avatar_writer.png': 'writer',
    'assets/images/demo_avatar_director.png': 'director',
    'assets/images/demo_avatar_sound.png': 'sound',
  };

  /// Resolve retired defaults at display time, preserving saved custom choices.
  static String memberImage(String memberId, {String? savedImage}) {
    if (savedImage != null &&
        savedImage.trim().isNotEmpty &&
        !_retiredMemberImages.containsKey(savedImage)) {
      return savedImage;
    }
    return memberImages[memberId] ?? memberImages['popi']!;
  }

  /// Explicit image overrides may also contain a known retired Bot asset.
  static String normalizeAvatarAsset(String path) {
    final memberId = _retiredMemberImages[path];
    return memberId == null ? path : memberImage(memberId);
  }

  static const direction =
      '园艺种植加情绪疗愈，通过分享自家种植的花卉蔬果，了解自身如何通过劳作获得多巴胺以及对待万物生命循环的思考';
  static const positioning =
      '这是一个聚焦校园与情感的账号，以 AI 真人剧情短片为载体，讲述青春里的心动、友情、陪伴与成长。\n\n从教室里的悄悄关注，到放学路上的并肩同行，我们将那些平凡却难忘的瞬间，化作温暖治愈的故事。\n\n希望每一个愿意分享感受的人，都能在别人的故事里，找到属于自己的青春回响。';
  static const script =
      '## 奶茶店的午后\n\n**场景一 · 午后，街角**\n\n爱丽丝推开奶茶店的门，熟悉的风铃响起。窗边坐着一个许久未见的朋友。\n\n**场景二 · 重逢**\n\n「好久不见，你还是喜欢三分糖吗？」\n\n她笑着点头，阳光落在两杯奶茶之间。\n\n**镜头建议**\n\n1. 街角远景，缓慢推进。\n2. 风铃特写，切人物视线。\n3. 两人对坐，以暖色中景收尾。';

  static List<DemoAsset> assets() => [
    const DemoAsset(
      id: 'milk',
      title: '奶茶店的午后',
      kind: DemoAssetKind.image,
      cover: 'assets/images/demo_milk_tea.png',
      sessionId: 'alice',
    ),
    const DemoAsset(
      id: 'sport',
      title: '运动与色彩',
      kind: DemoAssetKind.image,
      cover: 'assets/images/demo_color_sport.png',
      sessionId: 'ding',
    ),
    const DemoAsset(
      id: 'weekend',
      title: '周末出游成片',
      kind: DemoAssetKind.video,
      cover: 'assets/images/demo_weekend.png',
      media: 'assets/images/demo_video.mp4',
      sessionId: 'alice',
    ),
    const DemoAsset(
      id: 'weekend2',
      title: '午后的故事',
      kind: DemoAssetKind.video,
      cover: 'assets/images/demo_weekend_2.png',
      media: 'assets/images/demo_video.mp4',
      sessionId: 'short',
    ),
    const DemoAsset(
      id: 'script',
      title: '奶茶店的重逢',
      kind: DemoAssetKind.script,
      cover: 'assets/images/demo_milk_tea.png',
      body: script,
      sessionId: 'alice',
    ),
    const DemoAsset(
      id: 'audio',
      title: '午后轻音乐',
      kind: DemoAssetKind.audio,
      cover: 'assets/images/demo_weekend.png',
      media: 'assets/images/demo_audio.mp4',
      sessionId: 'alice',
    ),
    for (var i = 1; i <= 5; i++)
      DemoAsset(
        id: 'scene$i',
        title: '爱丽丝的场景 $i',
        kind: DemoAssetKind.image,
        cover: 'assets/images/demo_scene_$i.png',
        sessionId: 'inspiration',
      ),
  ];

  static List<DemoSession> sessions() => [
    const DemoSession(
      id: 'ding',
      title: '叮叮制作组',
      kind: DemoSessionKind.conversation,
      members: ['designer'],
      roles: ['alice', 'er', 'dou'],
      time: '15:57',
      direction: direction,
      positioning: positioning,
      messages: [
        DemoMessage(id: 'ding0', text: '今天想让爱丽丝经历什么故事？\n也可以从上次的灵感继续。'),
        DemoMessage(id: 'ding1', text: '给这三个角色生成选题', user: true),
      ],
    ),
    const DemoSession(
      id: 'alice',
      title: '爱丽丝视频',
      kind: DemoSessionKind.project,
      members: ['popi'],
      roles: ['alice'],
      unread: 2,
      time: '昨天',
      direction: direction,
      positioning: positioning,
      messages: [
        DemoMessage(id: 'alice0', text: '今天想让爱丽丝经历什么故事？\n也可以从上次的灵感继续。'),
        DemoMessage(id: 'alice1', text: '让她在奶茶店遇见一个意想不到的老朋友。', user: true),
        DemoMessage(id: 'alice2', text: '爱丽丝逛街的画面已生成', assetIds: ['milk']),
      ],
    ),
    const DemoSession(
      id: 'inspiration',
      title: '灵感到成片',
      kind: DemoSessionKind.workflow,
      members: ['popi', 'writer', 'director'],
      roles: ['alice', 'er', 'dou'],
      time: '昨天',
      direction: direction,
      positioning: positioning,
      messages: [
        DemoMessage(id: 'ins0', text: '今天想让爱丽丝经历什么故事？\n也可以从上次的灵感继续。'),
        DemoMessage(id: 'ins1', text: '帮我批量生成五张关于爱丽丝角色的场景图', user: true),
        DemoMessage(
          id: 'ins2',
          text: '三视图已生成，你看看这个造型喜欢吗？',
          assetIds: ['scene1', 'scene2', 'scene3', 'scene4', 'scene5'],
        ),
      ],
    ),
    const DemoSession(
      id: 'campus',
      title: '校园vlog',
      kind: DemoSessionKind.conversation,
      members: ['director', 'popi', 'writer', 'designer'],
      roles: [],
      time: '12:14',
      messages: [
        DemoMessage(id: 'campus0', text: '制作一个戴眼镜的校园男孩形象', user: true),
      ],
    ),
    const DemoSession(
      id: 'doudou',
      title: '豆豆的项目',
      kind: DemoSessionKind.project,
      members: ['writer'],
      roles: ['dou'],
      unread: 1,
      time: '7天前',
      messages: [DemoMessage(id: 'dou0', text: '让人设更加讨喜一点', user: true)],
    ),
    const DemoSession(
      id: 'old',
      title: '爱丽丝的对话',
      kind: DemoSessionKind.conversation,
      members: ['sound'],
      roles: ['alice'],
      time: '30天前',
      messages: [DemoMessage(id: 'old0', text: '三视图已生成，你看看这个造型喜欢吗？')],
    ),
    const DemoSession(
      id: 'short',
      title: '短片创作组',
      kind: DemoSessionKind.project,
      members: ['popi', 'writer'],
      roles: ['alice', 'er'],
      time: '昨天',
      messages: [DemoMessage(id: 'short0', text: '三视图已生成，你看看这个造型喜欢吗？')],
    ),
  ];
}
