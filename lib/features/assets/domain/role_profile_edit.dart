import 'dart:convert';

import 'library_role.dart';

enum RoleProfileFieldType {
  positioning,
  style,
  audience,
  tags,
  appearance,
  boundaries,
  custom,
}

/// Keeps server field identities and value types while editing a profile.
class RoleProfileField {
  const RoleProfileField({
    required this.id,
    required this.type,
    required this.value,
    this.label = '',
    this.profileDataKey,
    this.editable = true,
  });

  final String id;
  final RoleProfileFieldType type;
  final Object? value;
  final String label;
  final String? profileDataKey;
  final bool editable;
  String get text => value is List
      ? (value as List).map(roleProfileText).join('、')
      : roleProfileText(value);
}

String roleProfileText(Object? value) {
  if (value is String) return value.trim();
  if (value is List) {
    return value
        .map(roleProfileText)
        .where((text) => text.isNotEmpty)
        .join(' / ');
  }
  if (value is num || value is bool) return value.toString();
  if (value is Map) return jsonEncode(value);
  return '';
}

/// Edits the displayed overview and server profile data using the Web save payload.
class RoleProfileEdit {
  RoleProfileEdit.fromRole(LibraryRole role)
    : profile = role.profile,
      fields = [
        RoleProfileField(
          id: 'expressionStyle',
          type: RoleProfileFieldType.style,
          value: role.profile['expressionStyle'] ?? role.profile['personality'],
        ),
        RoleProfileField(
          id: 'targetAudience',
          type: RoleProfileFieldType.audience,
          value: role.profile['targetAudience'],
        ),
        RoleProfileField(
          id: 'contentTags',
          type: RoleProfileFieldType.tags,
          value: role.profile['contentTags'],
        ),
      ] {
    final data = profile['profileData'];
    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final field = entry.value;
        fields.add(
          RoleProfileField(
            id: 'profileData-$key',
            type: switch (key) {
              'positioning' ||
              'description' => RoleProfileFieldType.positioning,
              'appearance' => RoleProfileFieldType.appearance,
              'boundaries' ||
              'expressionBoundaries' => RoleProfileFieldType.boundaries,
              _ => RoleProfileFieldType.custom,
            },
            profileDataKey: key,
            label: field is Map ? roleProfileText(field['label']) : key,
            value: field is Map && field.containsKey('value')
                ? field['value']
                : field,
          ),
        );
      }
    }
  }

  final Map<String, dynamic> profile;
  final List<RoleProfileField> fields;

  static List<String> _splitList(String value) => value
      .split(RegExp(r'[\n、,，]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  static Object? _editedValue(String content, RoleProfileField field) {
    if (content == field.text) return field.value;
    if (field.value is List) return _splitList(content);
    if (field.value is num) {
      final number = num.tryParse(content.trim());
      return number != null && number.isFinite ? number : field.value;
    }
    if (field.value is bool) {
      return {'true', '1', 'yes', '是'}.contains(content.trim().toLowerCase());
    }
    return content.trim();
  }

  Map<String, Object?> savedProfile(
    Map<String, String> values, {
    Map<String, String> fieldLabels = const {},
  }) {
    final previous = profile['profileData'];
    final data = previous is Map
        ? Map<String, Object?>.from(previous)
        : <String, Object?>{};
    for (final field in fields.where((field) => field.profileDataKey != null)) {
      if (!values.containsKey(field.id) &&
          !data.containsKey(field.profileDataKey)) {
        continue;
      }
      final content = values[field.id] ?? field.text;
      data[field.profileDataKey!] = {
        'label': field.label.isNotEmpty
            ? field.label
            : fieldLabels[field.id] ?? field.profileDataKey!,
        'value': _editedValue(content, field),
      };
    }
    return {
      'expressionStyle': values['expressionStyle']?.trim() ?? '',
      'targetAudience': values['targetAudience']?.trim() ?? '',
      'contentTags': _splitList(values['contentTags'] ?? ''),
      'profileData': data,
    };
  }
}
