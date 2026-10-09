import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/features/ip_guide/domain/ip_guide_draft.dart';

void main() {
  test('initial draft starts empty with short film as the content format', () {
    final draft = IpGuideDraft();
    expect(draft.firstIncompleteStep, 1);
    expect(draft.directions.isEmpty, isTrue);
    expect(draft.feelings.isEmpty, isTrue);
    expect(draft.presentation, isNull);
    expect(draft.format, IpContentFormat.shortFilm);
    expect(draft.nickname, isEmpty);
  });

  test('selection preserves order and rejects a third choice', () {
    final selection = IpGuideSelection<IpContentDirection>();
    expect(selection.toggle(IpContentDirection.campus), isTrue);
    expect(selection.toggle(IpContentDirection.emotion), isTrue);
    expect(selection.toggle(IpContentDirection.growth), isFalse);
    expect(selection.values, [
      IpContentDirection.campus,
      IpContentDirection.emotion,
    ]);
    expect(() => selection.values.clear(), throwsUnsupportedError);
    selection.toggle(IpContentDirection.campus);
    expect(selection.values, [IpContentDirection.emotion]);
    selection.toggle(IpContentDirection.growth);
    expect(selection.values, [
      IpContentDirection.emotion,
      IpContentDirection.growth,
    ]);
    selection.toggle(IpContentDirection.emotion);
    selection.toggle(IpContentDirection.growth);
    expect(selection.isEmpty, isTrue);
  });

  test(
    'custom text replaces presets and a preset clears the custom answer',
    () {
      final selection = IpGuideSelection<IpAudienceFeeling>();
      selection.toggle(IpAudienceFeeling.authentic);
      selection.customText = '  好奇  ';
      expect(selection.values, isEmpty);
      expect(selection.isEmpty, isFalse);
      selection.toggle(IpAudienceFeeling.surprising);
      expect(selection.customText, isEmpty);
      expect(selection.values, [IpAudienceFeeling.surprising]);
      selection.customText = '新感受';
      selection.customText = '   ';
      expect(selection.isEmpty, isTrue);
    },
  );

  test('validation points at the first incomplete step', () {
    final draft = IpGuideDraft();
    draft.directions.customText = '美食';
    expect(draft.firstIncompleteStep, 2);
    draft.feelings.toggle(IpAudienceFeeling.healing);
    expect(draft.firstIncompleteStep, 3);
    draft.presentation = IpPresentation.animation3d;
    expect(draft.firstIncompleteStep, 4);
    draft.audience.toggle(IpTargetAudience.students);
    expect(draft.firstIncompleteStep, isNull);
    draft.directions.customText = '';
    expect(draft.firstIncompleteStep, 1);
  });
}
