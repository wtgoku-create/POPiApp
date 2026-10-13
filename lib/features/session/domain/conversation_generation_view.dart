import '../../role_guide/domain/home_creation.dart';
import 'conversation_snapshot.dart';

/// 卡片中的历史方案与可编辑输入分开，界面不解析网络 JSON。
class ConversationGenerationView {
  ConversationGenerationView(ConversationBlock card)
    : mediaType = card.isHomePlan ? 'video' : card.mediaType,
      threeView = card.isThreeView,
      useProfile = card.roleImage?['useProfile'] != false,
      referencePurpose =
          card.roleImage?['referencePurpose'] as String? ?? 'identity',
      requirements = card.roleImage?['requirements'] as String? ?? '',
      template = card.data['roleTemplate'] is Map
          ? conversationMap(card.data['roleTemplate'])
          : const {},
      referenceMediaId =
          card.roleImage?['referenceMediaId']?.toString() ??
          conversationMaps(card.planItems.firstOrNull?['references'])
              .where((ref) => ref['purpose'] != 'style')
              .firstOrNull?['mediaId']
              ?.toString(),
      references = conversationMaps(card.planItems.firstOrNull?['references']),
      config = card.planItems.firstOrNull?['modelId'] == null
          ? null
          : HomeConfig.fromJson(card.planItems.first),
      prompt = card.data['presentation'] is Map
          ? (conversationMap(card.data['presentation'])['requirements'] ??
                    card.planItems.firstOrNull?['prompt'] ??
                    card.body)
                .toString()
          : card.planItems.firstOrNull?['prompt'] as String? ?? card.body,
      hasProfile = _hasInput(card.previewRole?.data['profile']),
      configurationLines = card.configuration
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList(),
      storyHasHeading =
          card.homeTopic?.body.contains('故事梗概') == true ||
          RegExp(
            r'^#{1,6} ',
            multiLine: true,
          ).hasMatch(card.homeTopic?.body ?? ''),
      storyHook =
          card.homeTopic?.hook.isNotEmpty == true &&
              !card.homeTopic!.body.contains(card.homeTopic!.hook)
          ? card.homeTopic!.hook
          : '';
  final String mediaType;
  final bool threeView;
  final bool useProfile;
  final String referencePurpose;
  final String requirements;
  final Map<String, Object?> template;
  final String? referenceMediaId;
  final List<Map<String, Object?>> references;
  final HomeConfig? config;
  final String prompt;
  final bool hasProfile;
  final List<String> configurationLines;
  final bool storyHasHeading;
  final String storyHook;
  String? get templateId => template['id']?.toString();
  String get templateTitle => template['title'] as String? ?? '';
  List<String> referenceIds(
    String? selectedReference,
    String? templateMediaId,
  ) => {
    if (threeView) ...[
      if (selectedReference != null) selectedReference,
      if (templateMediaId != null) templateMediaId,
    ] else ...[
      for (final ref in references)
        if (ref['mediaId'] != null) ref['mediaId'].toString(),
    ],
  }.toList();
}

bool _hasInput(Object? value) => value is String
    ? value.trim().isNotEmpty
    : value is List
    ? value.any(_hasInput)
    : value is Map
    ? value.entries.any(
        (entry) => entry.key != 'label' && _hasInput(entry.value),
      )
    : value != null;
