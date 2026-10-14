import '../../../core/utils/app_url.dart';
import '../../assets/domain/library_role.dart';
import '../../assets/domain/role_profile_edit.dart';
import 'conversation_snapshot.dart';

/// Projects the saved role version into the same ordered fields used by Web.
class ConversationRoleProfile {
  ConversationRoleProfile.fromBlock(ConversationBlock block) {
    final data = block.data;
    final profile = data['profile'] is Map
        ? conversationMap(data['profile'])
        : <String, Object?>{};
    title = block.title.isNotEmpty
        ? block.title
        : roleProfileText(profile['title']);
    description = roleProfileText(
      profile['description'] ?? data['description'],
    );
    updated = block.action == 'edited';
    published = block.action == 'published' && block.status == 'active';
    final avatar = AppUrl.resolve(roleProfileText(data['avatar']));
    final threeView = AppUrl.resolve(roleProfileText(data['threeViewImage']));
    portrait = updated && threeView.isNotEmpty
        ? threeView
        : avatar.isNotEmpty
        ? avatar
        : threeView;
    snapshotRole = LibraryRole(
      id: block.referenceId,
      title: title,
      description: description,
      avatar: portrait,
      profile: profile,
      canRead: true,
      profileComplete: data['profileComplete'] == true,
      profileVersion: num.tryParse(data['version']?.toString() ?? ''),
      profileVersionId: block.reference?['versionId']?.toString(),
    );
    showProfileCard =
        (block.status != 'active' && block.action != 'cast') ||
        published ||
        ['created', 'edited'].contains(block.action);
    overview = [
      for (final key in [
        'description',
        'expressionStyle',
        'targetAudience',
        'contentTags',
      ])
        if (_fieldText(profile[key]).isNotEmpty)
          (key, _fieldText(profile[key])),
    ];
    final profileData = profile['profileData'];
    fullFields = [
      if (profileData is Map)
        for (final entry in conversationMap(profileData).entries)
          if (entry.value is Map)
            (
              roleProfileText(conversationMap(entry.value)['label']).isEmpty
                  ? entry.key
                  : roleProfileText(conversationMap(entry.value)['label']),
              _fieldText(conversationMap(entry.value)['value'], separator: '、'),
            ),
    ];
    fields = [('title', title), ...overview, ...fullFields];
  }

  late final String title;
  late final String description;
  late final String portrait;
  late final LibraryRole snapshotRole;
  late final bool updated;
  late final bool published;
  late final bool showProfileCard;
  late final List<(String, String)> overview;
  late final List<(String, String)> fullFields;
  late final List<(String, String)> fields;

  static String _fieldText(Object? value, {String separator = ', '}) =>
      value is List
      ? value
            .map((item) => _fieldText(item, separator: separator))
            .where((text) => text.isNotEmpty)
            .join(separator)
      : roleProfileText(value);
}
