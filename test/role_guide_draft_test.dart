import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/role_guide/domain/role_guide_draft.dart';

void main() {
  final roles = List.generate(
    7,
    (i) => LibraryRole(id: '$i', title: 'Role $i', description: ''),
  );

  test(
    'draft caps the project at five and uses the same ordered characters as cast',
    () {
      final draft = RoleGuideDraft();
      expect(draft.step, RoleGuideStep.roles);
      expect(draft.roles, isEmpty);
      expect(draft.cast, isEmpty);
      expect(draft.settings, isNull);
      expect(draft.startProject(), isFalse);
      for (final role in roles.take(5)) {
        expect(draft.toggleRole(role), isTrue);
      }
      expect(draft.toggleRole(roles[6]), isFalse);
      expect(draft.startProject(), isTrue);
      expect(draft.step, RoleGuideStep.story);
      expect(draft.cast, draft.roles);
      draft.toggleRole(roles[0]);
      expect(draft.roles.first.id, '1');
      expect(draft.cast.map((role) => role.id), ['1', '2', '3', '4']);
      expect(draft.toggleRole(roles[6]), isTrue);
      expect(draft.roles.last.id, '6');
      expect(() => draft.roles.clear(), throwsUnsupportedError);
    },
  );

  test('updated profiles and settings survive step changes until reset', () {
    final draft = RoleGuideDraft();
    draft.toggleRole(roles[0]);
    draft.updateRole(
      const LibraryRole(id: '0', title: 'Updated', description: ''),
    );
    expect(draft.roles.first.title, 'Updated');
    expect(draft.cast.first.title, 'Updated');
    draft.settings = const RoleGenerationSettings(quantity: 3);
    draft.step = RoleGuideStep.production;
    draft.refreshStories();
    expect(draft.step, RoleGuideStep.story);
    expect(draft.storyBatch, 1);
    expect(draft.settings!.quantity, 3);
    draft.clear();
    expect(draft.step, RoleGuideStep.roles);
    expect(draft.roles, isEmpty);
    expect(draft.cast, isEmpty);
    expect(draft.settings, isNull);
    expect(draft.storyBatch, 0);
  });

  test(
    'role edits commit atomically and reject an empty or oversized cast',
    () {
      final draft = RoleGuideDraft();
      draft.toggleRole(roles[0]);
      draft.startProject();
      draft.storyIndex = 2;
      draft.storyBatch = 1;
      expect(draft.replaceRoles([]), isFalse);
      expect(draft.replaceRoles(roles), isFalse);
      expect(draft.roles.single.id, '0');
      expect(draft.storyIndex, 2);
      expect(draft.replaceRoles([roles[2], roles[1], roles[2]]), isTrue);
      expect(draft.roles.map((role) => role.id), ['2', '1']);
      expect(draft.storyIndex, 0);
      expect(draft.storyBatch, 0);
    },
  );

  test('image and video dimensions follow independent preferences', () {
    const initial = RoleGenerationSettings();
    expect(initial.dimensions(image: false), (width: 1280, height: 720));
    final changed = initial.copyWith(
      videoResolution: 1080,
      videoRatio: GenerationRatio.portrait,
      imageRatio: GenerationRatio.square,
    );
    expect(changed.dimensions(image: false), (width: 1080, height: 1920));
    expect(changed.dimensions(image: true), (width: 720, height: 720));
    expect(initial.videoResolution, 720);
    expect(initial.imageRatio, GenerationRatio.landscape);
  });
}
