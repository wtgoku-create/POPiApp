import 'dart:convert';

import '../../assets/domain/library_role.dart';
import '../../assets/domain/role_profile_edit.dart';

typedef HomeRoleField = ({String id, String label, Object? value});

/// Matches the Web creation editor's sections and value conversion.
class HomeRoleProfileEdit {
  HomeRoleProfileEdit(LibraryRole role) : profile = role.profile {
    fields = [
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
    if (field.value is List) {
      return (field.value as List)
          .map((value) => value is String ? value : jsonEncode(value))
          .join('、');
    }
    return field.value == null
        ? ''
        : field.value is String
        ? field.value as String
        : jsonEncode(field.value);
  }

  Map<String, Object?> savedProfile(Map<String, String> values) {
    final result = Map<String, Object?>.from(profile);
    final data = <String, Object?>{};
    for (final field in fields) {
      final input = values[field.id] ?? text(field);
      final value = field.id == 'contentTags' || field.value is List
          ? input
                .split(RegExp(r'[\n、,，]+'))
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList()
          : field.value is num
          ? _number(input, field.value as num)
          : field.value is bool
          ? {'true', '1', 'yes', '是'}.contains(input.trim().toLowerCase())
          : input.trim();
      if (field.id.startsWith('profileData-')) {
        final key = field.id.substring('profileData-'.length);
        data[key] = {
          'label': (profile['profileData'] as Map)[key]['label'] ?? field.label,
          'value': value,
        };
      } else {
        result[field.id] = value;
      }
    }
    result['profileData'] = data;
    return result;
  }

  static num _number(String input, num previous) {
    final number = input.trim().isEmpty ? 0 : num.tryParse(input.trim());
    return number != null && number.isFinite ? number : previous;
  }
}
