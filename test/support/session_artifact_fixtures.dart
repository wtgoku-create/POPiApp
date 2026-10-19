import 'package:popi_ai_app/features/session/data/session_artifact_repository.dart';
import 'package:popi_ai_app/features/session/domain/session_artifact.dart';

class FixtureSessionArtifactRepository extends SessionArtifactRepository {
  const FixtureSessionArtifactRepository();

  @override
  Future<List<SessionArtifact>> list(String? sessionId) async => [
    const SessionArtifact(
      id: 'mock-role',
      type: SessionArtifactType.image,
      title: '萌宠角色三视图',
      summary: '正面、侧面、背面与形象展示',
      metadata: 'PNG · 1 张',
      previewAsset: 'assets/images/session_artifact_role.png',
    ),
    const SessionArtifact(
      id: 'mock-script',
      type: SessionArtifactType.script,
      title: '《围巾不见了》分镜剧本',
      summary:
          '清晨，小小的萌宠发现心爱的围巾不见了。它翻遍房间，又追着一抹红色跑进花园，最终发现这份熟悉的温暖，正在陪伴另一个需要帮助的朋友。',
      metadata: 'DOCX · 6 个镜头 · 约 32 秒',
      shots: [
        SessionArtifactShot(
          '镜头 01 · 发现不见了',
          '00:00–00:04',
          '暖光落在床边，萌宠伸了个懒腰，习惯性地摸向脖子，却发现空空的。镜头从房间全景推进到惊讶的表情。',
          '“咦，我的围巾呢？”',
        ),
        SessionArtifactShot(
          '镜头 02 · 翻找房间',
          '00:04–00:09',
          '它掀开枕头，钻进床底，又踮起脚查看衣架。几个连续的小动作切成轻快的蒙太奇，最后只找出一只袜子。',
          '“这里没有，那里也没有……”',
        ),
        SessionArtifactShot(
          '镜头 03 · 红色的线索',
          '00:09–00:14',
          '窗外闪过一抹红色。萌宠停下脚步，耳朵一下竖起，推开门向花园跑去。镜头跟随它穿过晃动的花丛。',
          '“我看见你啦！”',
        ),
        SessionArtifactShot(
          '镜头 04 · 意外的发现',
          '00:14–00:20',
          '花园角落里，一只小伙伴正裹着那条围巾打盹。萌宠伸出手，又在看见对方蜷缩的身体后轻轻停住。',
          '环境声渐弱，只留下轻轻的呼吸声。',
        ),
        SessionArtifactShot(
          '镜头 05 · 分享温暖',
          '00:20–00:27',
          '萌宠将围巾的一角仔细掖好，坐到小伙伴身旁。对方睁开眼，两人相视一笑，共同裹住柔软的围巾。',
          '“原来，你比我更需要它。”',
        ),
        SessionArtifactShot(
          '镜头 06 · 温暖的结尾',
          '00:27–00:32',
          '镜头缓缓拉远，两位伙伴坐在花丛里，围巾随着微风轻轻摆动。画面停留在温暖的拥抱，随后淡出。',
          '字幕：“分享一点温暖，就多一个朋友。”',
        ),
      ],
    ),
    SessionArtifact(
      id: 'mock-video',
      type: SessionArtifactType.video,
      title: '角色故事短片',
      summary: '生成完成',
      metadata: 'MP4 · 00:32',
      previewAsset: 'assets/images/session_artifact_video.png',
      videoUrl: Uri.parse(
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      ),
    ),
  ];
}
