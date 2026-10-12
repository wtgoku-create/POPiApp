import 'dart:convert';

import '../../assets/domain/library_role.dart';
import '../../assets/domain/role_profile_edit.dart';

typedef HomeRoleField = ({String id, String label, Object? value});

/// Edits the creation snapshot, preserving custom field identities and values.
class HomeRoleProfileEdit {
  HomeRoleProfileEdit(LibraryRole role) : profile = role.profile {
    fields = [
      (id: 'title', label: 'title', value: profile['title'] ?? role.title),
      (
        id: 'description',
        label: 'description',
        value: profile['description'] ?? role.description,
      ),
      for (final key in ['expressionStyle', 'targetAudience', 'contentTags'])
        (id: key, label: key, value: profile[key]),
      if (profile['profileData'] case final Map data)
        for (final entry in data.entries)
          if (entry.value case final Map field)
            (
              id: 'profileData-${entry.key}',
              label: roleProfileText(field['label']).isEmpty
                  ? entry.key.toString()
                  : roleProfileText(field['label']),
              value: field['value'],
            ),
    ];
  }

  final Map<String, Object?> profile;
  late final List<HomeRoleField> fields;

  String text(HomeRoleField field) {
    if (field.id == 'contentTags' && field.value is List) {
      return (field.value as List).map(roleProfileText).join('、');
    }
    return field.value == null
        ? ''
        : field.value is String
        ? field.value as String
        : jsonEncode(field.value);
  }

  Map<String, Object?> savedProfile(Map<String, String> values) {
    final result = Map<String, Object?>.from(profile);
    final data = profile['profileData'] is Map
        ? Map<String, Object?>.from(profile['profileData'] as Map)
        : <String, Object?>{};
    for (final field in fields) {
      final input = values[field.id] ?? text(field);
      Object? value = field.value;
      if (input != text(field)) {
        if (field.id == 'contentTags') {
          value = input
              .split(RegExp(r'[\n、,，]+'))
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList();
        } else if (field.value is String || field.value == null) {
          value = input.trim();
        } else {
          try {
            value = jsonDecode(input);
          } on FormatException {
            throw FormatException('Invalid profile field', field.id);
          }
        }
      }
      if (field.id.startsWith('profileData-')) {
        final key = field.id.substring('profileData-'.length);
        data[key] = {
          ...Map<String, Object?>.from(data[key] as Map),
          'value': value,
        };
      } else {
        result[field.id] = value;
      }
    }
    result['profileData'] = data;
    return result;
  }
}
