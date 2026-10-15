import 'dart:convert';

/// Converts current prompts and historical shot data into one display body.
class HomeStoryboard {
  const HomeStoryboard({required this.shots, this.modelPrompt});

  final List<HomeStoryboardShot> shots;
  final String? modelPrompt;

  static String displayText(String body) {
    try {
      final Object? value = jsonDecode(body);
      if (value is String) return value;
      if (value is Map && value['modelPrompt'] is String) {
        return value['modelPrompt'] as String;
      }
    } on FormatException {
      return body;
    }
    final storyboard = tryParse(body);
    if (storyboard == null) return body;
    return [
      for (var index = 0; index < storyboard.shots.length; index++)
        '${index + 1} · ${storyboard.shots[index].duration}s\n'
            '${storyboard.shots[index].description}',
    ].join('\n\n');
  }

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
