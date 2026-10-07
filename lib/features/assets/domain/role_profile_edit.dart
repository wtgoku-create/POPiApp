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

/// Builds the editable fields and the same save payload used by the Web app.
class RoleProfileEdit {
  RoleProfileEdit.fromRole(LibraryRole role)
    : profile = role.profile,
      fields = [
        RoleProfileField(
          id: 'description',
          type: RoleProfileFieldType.positioning,
          value: role.description,
          profileDataKey: 'positioning',
        ),
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
        if (key == 'positioning' || key == 'description') {
          fields.removeWhere((field) => field.id == 'description');
        }
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
            value: field is Map ? field['value'] : field,
          ),
        );
      }
    }
    if (fields.every((field) => field.profileDataKey != 'appearance') &&
        roleProfileText(profile['appearance']).isNotEmpty) {
      fields.add(
        RoleProfileField(
          id: 'appearance',
          type: RoleProfileFieldType.appearance,
          value: profile['appearance'],
          profileDataKey: 'appearance',
        ),
      );
    }
    if (fields.every(
      (field) => ![
        'boundaries',
        'expressionBoundaries',
      ].contains(field.profileDataKey),
    )) {
      fields.add(
        RoleProfileField(
          id: 'boundaries',
          type: RoleProfileFieldType.boundaries,
          value: profile['boundaries'] ?? profile['expressionBoundaries'],
          profileDataKey:
              profile.containsKey('expressionBoundaries') &&
                  !profile.containsKey('boundaries')
              ? 'expressionBoundaries'
              : 'boundaries',
        ),
      );
    }
  }

  final Map<String, dynamic> profile;
  final List<RoleProfileField> fields;

  static List<String> _splitList(String value) => value
      .split(RegExp(r'[\n、,，]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

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
        'value': content == field.text
            ? field.value
            : field.value is List
            ? _splitList(content)
            : content.trim(),
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
