import 'package:flutter/foundation.dart';

/// A reusable assistant identity; its execution slot stays compatible with DSH.
@immutable
class DemoAssistantProfile {
  const DemoAssistantProfile({
    required this.id,
    required this.memberId,
    this.name = '',
    this.instructions = '',
    this.avatarAsset = '',
    this.avatarColor,
    this.skillIds = const [],
  });

  final String id;
  final String memberId;
  final String name;
  final String instructions;
  final String avatarAsset;
  final int? avatarColor;
  final List<String> skillIds;

  bool get isBuiltIn => id.startsWith('builtin:');

  Map<String, Object?> toJson() => {
    'id': id,
    'memberId': memberId,
    'name': name,
    'instructions': instructions,
    'avatarAsset': avatarAsset,
    'avatarColor': avatarColor,
    'skillIds': skillIds,
  };

  factory DemoAssistantProfile.fromJson(Map<String, Object?> json) =>
      DemoAssistantProfile(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        name: json['name'] as String? ?? '',
        instructions: json['instructions'] as String? ?? '',
        avatarAsset: json['avatarAsset'] as String? ?? '',
        avatarColor: (json['avatarColor'] as num?)?.toInt(),
        skillIds: List<String>.from(json['skillIds'] as List? ?? const []),
      );

  DemoAssistantProfile copyWith({
    String? id,
    String? memberId,
    String? name,
    String? instructions,
    String? avatarAsset,
    int? avatarColor,
    List<String>? skillIds,
  }) => DemoAssistantProfile(
    id: id ?? this.id,
    memberId: memberId ?? this.memberId,
    name: name ?? this.name,
    instructions: instructions ?? this.instructions,
    avatarAsset: avatarAsset ?? this.avatarAsset,
    avatarColor: avatarColor ?? this.avatarColor,
    skillIds: skillIds ?? this.skillIds,
  );
}
