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
  });

  final String id;
  final String memberId;
  final String name;
  final String instructions;
  final String avatarAsset;
  final int? avatarColor;

  bool get isBuiltIn => id.startsWith('builtin:');

  DemoAssistantProfile copyWith({
    String? id,
    String? memberId,
    String? name,
    String? instructions,
    String? avatarAsset,
    int? avatarColor,
  }) => DemoAssistantProfile(
    id: id ?? this.id,
    memberId: memberId ?? this.memberId,
    name: name ?? this.name,
    instructions: instructions ?? this.instructions,
    avatarAsset: avatarAsset ?? this.avatarAsset,
    avatarColor: avatarColor ?? this.avatarColor,
  );
}
