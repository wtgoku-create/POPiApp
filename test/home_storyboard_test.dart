import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_storyboard.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_storyboard_body.dart';

void main() {
  test('plain prompts and historical model prompts use one unchanged body', () {
    const prompt = '全片15秒，无BGM。\n镜头01｜00:00.000–00:15.000\n**保留原文**';
    for (final body in [
      prompt,
      jsonEncode(prompt),
      jsonEncode({'modelPrompt': prompt}),
      jsonEncode({'modelPrompt': prompt, 'shots': []}),
      jsonEncode({
        'modelPrompt': prompt,
        'shots': [
          {'duration': 3, 'description': 'Historical director description'},
        ],
      }),
    ]) {
      expect(HomeStoryboard.displayText(body), prompt);
    }
  });

  test(
    'legacy shots become ordered text while malformed data is preserved',
    () {
      final body = jsonEncode({
        'shots': [
          {'duration': 3, 'description': 'Wide shot\nAction'},
          {'duration': 1.5, 'description': 'Close-up'},
        ],
      });
      expect(
        HomeStoryboard.displayText(body),
        '1 · 3s\nWide shot\nAction\n\n2 · 1.5s\nClose-up',
      );
      for (final body in [
        '{broken',
        '{"shots":[]}',
        '{"shots":[{"duration":0,"description":"Invalid"}]}',
      ]) {
        expect(HomeStoryboard.displayText(body), body);
      }
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('prompt text wraps and remains selectable at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prompt = '镜头01\n**保留原文**\n${'LongPrompt' * 40}';
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [RoleStoryboardBody(body: prompt)],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        prompt,
      );
      expect(
        tester.getSize(find.byType(SelectableText)).width,
        lessThanOrEqualTo(width - 40),
      );
      expect(tester.takeException(), isNull);
    });
  }

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
