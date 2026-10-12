import 'home_creation.dart';

/// Separate video and image defaults belonging to a single conversation.
class SessionMediaPreferences {
  SessionMediaPreferences.fromJson(Map<String, Object?> json)
    : revision = json['revision'] as int,
      video = json['video'] == null
          ? null
          : HomeConfig.fromJson(homeObject(json['video'])),
      image = json['image'] == null
          ? null
          : HomeConfig.fromJson(homeObject(json['image']));

  final int revision;
  final HomeConfig? video;
  final HomeConfig? image;
}
