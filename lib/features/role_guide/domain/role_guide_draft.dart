import '../../assets/domain/library_role.dart';

enum RoleGuideStep { roles, cast, story, production }

enum GenerationModel {
  sora('Sora 2'),
  veo('Veo 3.1'),
  jimeng('Jimeng 3.0'),
  kling('Kling-v2-5T'),
  vidu('Vidu q3-pro');

  const GenerationModel(this.label);
  final String label;
}

enum GenerationRatio {
  landscape(16, 9),
  photo(3, 2),
  classic(4, 3),
  square(1, 1),
  portrait(9, 16),
  portraitPhoto(2, 3),
  portraitClassic(3, 4);

  const GenerationRatio(this.width, this.height);
  final int width;
  final int height;
  String get label => '$width:$height';
}

/// Immutable settings allow a dismissed sheet to leave the saved plan intact.
class RoleGenerationSettings {
  const RoleGenerationSettings({
    this.model = GenerationModel.sora,
    this.imageResolution = 720,
    this.imageRatio = GenerationRatio.landscape,
    this.videoResolution = 720,
    this.videoRatio = GenerationRatio.landscape,
    this.quantity = 1,
  });

  final GenerationModel model;
  final int imageResolution;
  final GenerationRatio imageRatio;
  final int videoResolution;
  final GenerationRatio videoRatio;
  final int quantity;

  RoleGenerationSettings copyWith({
    GenerationModel? model,
    int? imageResolution,
    GenerationRatio? imageRatio,
    int? videoResolution,
    GenerationRatio? videoRatio,
    int? quantity,
  }) => RoleGenerationSettings(
    model: model ?? this.model,
    imageResolution: imageResolution ?? this.imageResolution,
    imageRatio: imageRatio ?? this.imageRatio,
    videoResolution: videoResolution ?? this.videoResolution,
    videoRatio: videoRatio ?? this.videoRatio,
    quantity: quantity ?? this.quantity,
  );

  ({int width, int height}) dimensions({required bool image}) {
    final resolution = image ? imageResolution : videoResolution;
    final ratio = image ? imageRatio : videoRatio;
    final shortSide = ratio.width < ratio.height ? ratio.width : ratio.height;
    int dimension(int value) =>
        (resolution * value / shortSide / 2).round() * 2;
    return (width: dimension(ratio.width), height: dimension(ratio.height));
  }
}

/// A route-local plan; choices are ordered and the cast stays within the project.
class RoleGuideDraft {
  final _roles = <LibraryRole>[];
  final _cast = <LibraryRole>[];
  RoleGuideStep step = RoleGuideStep.roles;
  int storyIndex = 0;
  int storyBatch = 0;
  RoleGenerationSettings? settings;

  List<LibraryRole> get roles => List.unmodifiable(_roles);
  List<LibraryRole> get cast => List.unmodifiable(_cast);

  bool toggleRole(LibraryRole role) {
    final index = _roles.indexWhere((item) => item.id == role.id);
    if (index >= 0) {
      _roles.removeAt(index);
      _cast.removeWhere((item) => item.id == role.id);
      return true;
    }
    if (_roles.length >= 6) return false;
    _roles.add(role);
    return true;
  }

  bool toggleCast(LibraryRole role) {
    if (!_roles.any((item) => item.id == role.id)) return false;
    final index = _cast.indexWhere((item) => item.id == role.id);
    if (index >= 0) {
      _cast.removeAt(index);
      return true;
    }
    if (_cast.length >= 3) return false;
    _cast.add(role);
    return true;
  }

  void updateRole(LibraryRole role) {
    for (final list in [_roles, _cast]) {
      final index = list.indexWhere((item) => item.id == role.id);
      if (index >= 0) list[index] = role;
    }
  }

  bool startProject() {
    if (_roles.isEmpty) return false;
    step = RoleGuideStep.cast;
    return true;
  }

  bool matchStories() {
    if (_cast.isEmpty) return false;
    step = RoleGuideStep.story;
    return true;
  }

  void refreshStories() {
    storyBatch = (storyBatch + 1) % 2;
    storyIndex = 0;
    step = RoleGuideStep.story;
  }

  void clear() {
    _roles.clear();
    _cast.clear();
    step = RoleGuideStep.roles;
    storyIndex = 0;
    storyBatch = 0;
    settings = null;
  }
}
