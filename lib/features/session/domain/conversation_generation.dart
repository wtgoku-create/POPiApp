import '../../../core/utils/app_url.dart';
import '../../role_guide/domain/home_creation.dart';
import '../../role_guide/domain/session_media_preferences.dart';
import 'conversation_snapshot.dart';

/// 模型目录、会话偏好和可恢复的生成选择使用后端真实数据。
class ConversationGenerationOptions {
  const ConversationGenerationOptions({
    required this.models,
    required this.preferences,
    this.recovery,
  });
  final List<HomeModel> models;
  final SessionMediaPreferences preferences;
  final ConversationGenerationSelection? recovery;
}

/// 首次确认后固定全部输入，网络结果未知时禁止修改付费请求。
class ConversationGenerationSelection {
  const ConversationGenerationSelection({
    required this.config,
    required this.estimatedPoints,
    required this.mediaPreferencesRevision,
    this.roleTemplateId,
    this.roleTemplateTitle = '',
    this.roleTemplateMediaId,
    this.referenceMediaId,
    this.requirements = '',
    this.useProfile = true,
    this.referencePurpose = 'identity',
  });
  factory ConversationGenerationSelection.fromJson(Map<String, Object?> json) =>
      ConversationGenerationSelection(
        config: HomeConfig.fromJson(conversationMap(json['config'])),
        estimatedPoints: json['estimatedPoints'] as num,
        mediaPreferencesRevision: json['mediaPreferencesRevision'] as int,
        roleTemplateId: json['roleTemplateId'] as String?,
        roleTemplateTitle: json['roleTemplateTitle'] as String? ?? '',
        roleTemplateMediaId: json['roleTemplateMediaId'] as String?,
        referenceMediaId: json['referenceMediaId'] as String?,
        requirements: json['requirements'] as String? ?? '',
        useProfile: json['useProfile'] != false,
        referencePurpose: json['referencePurpose'] as String? ?? 'identity',
      );
  final HomeConfig config;
  final num estimatedPoints;
  final int mediaPreferencesRevision;
  final String? roleTemplateId;
  final String roleTemplateTitle;
  final String? roleTemplateMediaId;
  final String? referenceMediaId;
  final String requirements;
  final bool useProfile;
  final String referencePurpose;
  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'estimatedPoints': estimatedPoints,
    'mediaPreferencesRevision': mediaPreferencesRevision,
    'roleTemplateId': roleTemplateId,
    'roleTemplateTitle': roleTemplateTitle,
    'roleTemplateMediaId': roleTemplateMediaId,
    'referenceMediaId': referenceMediaId,
    'requirements': requirements,
    'useProfile': useProfile,
    'referencePurpose': referencePurpose,
  };
  Map<String, Object?> get roleImageConfiguration => {
    ...config.toJson(),
    'roleTemplateId': roleTemplateId,
    'referenceMediaId': referenceMediaId,
    'requirements': requirements,
    'useProfile': useProfile,
    'referencePurpose': referencePurpose,
  };
}

class ConversationRoleTemplate {
  const ConversationRoleTemplate({
    required this.id,
    required this.title,
    this.coverUrl = '',
    this.mediaId,
  });

  ConversationRoleTemplate.fromJson(Map<String, Object?> json)
    : id = json['id'].toString(),
      title = json['title'] as String,
      coverUrl = AppUrl.resolve(json['coverUrl'] as String? ?? ''),
      mediaId = json['mediaId']?.toString();
  final String id;
  final String title;
  final String coverUrl;
  final String? mediaId;
}
