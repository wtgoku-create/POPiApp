import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_role_profile_edit.dart';

void main() {
  test(
    'creation editor matches Web fields and preserves read-only profile values',
    () {
      final role = LibraryRole.fromJson({
        'id': 1,
        'profile': {
          'title': 'Character',
          'description': 'Original',
          'schemaVersion': 3,
          'appearance': 'Original appearance',
          'personality': 'Original personality',
          'purpose': 'Original purpose',
          'expressionStyle': 'Warm',
          'targetAudience': 'Students',
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
      expect(edit.fields.map((field) => field.id), [
        'expressionStyle',
        'targetAudience',
        'contentTags',
        'profileData-personality',
        'profileData-age',
        'profileData-details',
        'profileData-hobbies',
      ]);
      expect(edit.text(edit.fields.last), 'Reading');
      final saved = edit.savedProfile({
        'title': 'New name',
        'description': 'New introduction',
        'appearance': 'Changed appearance',
        'expressionStyle': '  Quiet  ',
        'contentTags': 'School、Friends, Family\nLove',
        'profileData-personality': 'Quiet',
        'profileData-age': '19',
        'profileData-hobbies': 'Writing、Reading',
      });
      expect(saved['title'], 'Character');
      expect(saved['description'], 'Original');
      expect(saved['appearance'], 'Original appearance');
      expect(saved['personality'], 'Original personality');
      expect(saved['purpose'], 'Original purpose');
      expect(saved['expressionStyle'], 'Quiet');
      expect(saved['schemaVersion'], 3);
      expect(saved['contentTags'], ['School', 'Friends', 'Family', 'Love']);
      final fields = saved['profileData'] as Map;
      expect(fields['personality'], {'label': 'Personality', 'value': 'Quiet'});
      expect((fields['age'] as Map)['value'], 19);
      expect((fields['details'] as Map)['value'], '{"favorite":"Books"}');
      expect((fields['hobbies'] as Map)['value'], ['Writing', 'Reading']);
      expect(
        (role.profile['profileData'] as Map)['personality']['value'],
        'Warm',
      );
      expect(
        ((edit.savedProfile({'profileData-details': 'Free text'})['profileData']
                as Map)['details']
            as Map)['value'],
        'Free text',
      );
    },
  );

  test(
    'creation custom fields use Web list, number and boolean conversion',
    () {
      final edit = HomeRoleProfileEdit(
        LibraryRole.fromJson({
          'id': 1,
          'profile': {
            'profileData': {
              'age': {'label': 'Age', 'value': 18},
              'active': {'label': 'Active', 'value': true},
              'hobbies': {
                'label': 'Hobbies',
                'value': ['Reading', 'Writing'],
              },
            },
          },
        }),
      );
      final saved = edit.savedProfile({
        'profileData-age': 'not a number',
        'profileData-active': '否',
        'profileData-hobbies': 'Music, Movies\nBooks，Travel',
      });
      final data = saved['profileData'] as Map;
      expect(data['age']['value'], 18);
      expect(data['active']['value'], false);
      expect(data['hobbies']['value'], ['Music', 'Movies', 'Books', 'Travel']);
      final affirmative = edit.savedProfile({'profileData-active': 'YES'});
      expect((affirmative['profileData'] as Map)['active']['value'], true);
    },
  );
}
