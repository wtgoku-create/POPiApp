import 'dart:convert';

/// Structured storyboard output; other bodies retain their Markdown rendering.
class HomeStoryboard {
  const HomeStoryboard({required this.shots, this.modelPrompt});

  final List<HomeStoryboardShot> shots;
  final String? modelPrompt;

  static HomeStoryboard? tryParse(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map || value['shots'] is! List) return null;
      final items = value['shots'] as List;
      if (items.isEmpty) return null;
      final shots = <HomeStoryboardShot>[];
      for (final item in items) {
        if (item is! Map) return null;
        final duration = item['duration'];
        final description = item['description'];
        if (duration is! num ||
            !duration.isFinite ||
            duration <= 0 ||
            description is! String) {
          return null;
        }
        shots.add(
          HomeStoryboardShot(duration: duration, description: description),
        );
      }
      final prompt = value['modelPrompt'];
      return HomeStoryboard(
        shots: shots,
        modelPrompt: prompt is String && prompt.trim().isNotEmpty
            ? prompt
            : null,
      );
    } on FormatException {
      return null;
    }
  }
}

class HomeStoryboardShot {
  const HomeStoryboardShot({required this.duration, required this.description});

  final num duration;
  final String description;
}
