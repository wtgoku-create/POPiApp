import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_role_profile_edit.dart';

void main() {
  test(
    'creation profile edits preserve labels, metadata and typed custom values',
    () {
      final role = LibraryRole.fromJson({
        'id': 1,
        'profile': {
          'title': 'Character',
          'description': 'Original',
          'schemaVersion': 3,
          'contentTags': ['School'],
          'profileData': {
            'personality': {
              'label': 'Personality',
              'value': 'Warm',
              'source': 'saved',
            },
            'age': {'label': 'Age', 'value': 18},
            'details': {
              'label': 'Details',
              'value': {'favorite': 'Books'},
            },
            'hobbies': {
              'label': 'Hobbies',
              'value': ['Reading'],
            },
          },
        },
      });
      final edit = HomeRoleProfileEdit(role);
      final saved = edit.savedProfile({
        'title': 'New name',
        'description': 'New introduction',
        'contentTags': 'School、Friends, Family\nLove',
        'profileData-personality': 'Quiet',
        'profileData-age': '19',
        'profileData-hobbies': '["Writing","Reading"]',
      });
      expect(saved['title'], 'New name');
      expect(saved['description'], 'New introduction');
      expect(saved['schemaVersion'], 3);
      expect(saved['contentTags'], ['School', 'Friends', 'Family', 'Love']);
      final fields = saved['profileData'] as Map;
      expect(fields['personality'], {
        'label': 'Personality',
        'value': 'Quiet',
        'source': 'saved',
      });
      expect((fields['age'] as Map)['value'], 19);
      expect((fields['details'] as Map)['value'], {'favorite': 'Books'});
      expect((fields['hobbies'] as Map)['value'], ['Writing', 'Reading']);
      expect(
        (role.profile['profileData'] as Map)['personality']['value'],
        'Warm',
      );
      expect(
        () => edit.savedProfile({'profileData-details': 'invalid'}),
        throwsFormatException,
      );
    },
  );
}
