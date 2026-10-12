import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_storyboard.dart';

void main() {
  test(
    'storyboard preserves shot order, fractional timing and decoded lines',
    () {
      final body = jsonEncode({
        'shots': [
          {
            'key': 'shot1',
            'duration': 3,
            'description': 'Wide shot\n**Action:** enters the room',
            'roles': [
              {'roleId': 243, 'profileVersionId': '12'},
            ],
          },
          {'duration': 1.5, 'description': 'Close-up'},
        ],
        'modelPrompt': 'Keep the camera steady.',
      });
      final storyboard = HomeStoryboard.tryParse(body)!;
      expect(storyboard.shots.map((shot) => shot.duration), [3, 1.5]);
      expect(
        storyboard.shots.first.description,
        'Wide shot\n**Action:** enters the room',
      );
      expect(storyboard.modelPrompt, 'Keep the camera steady.');
    },
  );

  test(
    'ordinary Markdown and invalid shots fall back without losing content',
    () {
      for (final body in [
        '## A script\n\nPlain content',
        '{broken',
        '{"shots":[]}',
        '{"shots":[{"duration":0,"description":"Invalid"}]}',
        '{"shots":[{"duration":"3","description":"Invalid"}]}',
        '{"shots":[{"duration":3,"description":null}]}',
        '{"shots":[{"duration":3,"description":"Valid"},null]}',
      ]) {
        expect(HomeStoryboard.tryParse(body), isNull);
      }
    },
  );
}
