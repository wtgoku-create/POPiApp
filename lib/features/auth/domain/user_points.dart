class UserPoints {
  const UserPoints({
    required this.availableMemberPoints,
    required this.availableOtherPoints,
    required this.availableTotalPoints,
    required this.consumePoints,
  });

  final int availableMemberPoints;
  final int availableOtherPoints;
  final int availableTotalPoints;
  final int consumePoints;

  factory UserPoints.fromJson(Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;

    return UserPoints(
      availableMemberPoints: number('availableMemberPoints'),
      availableOtherPoints: number('availableOtherPoints'),
      availableTotalPoints: number('availableTotalPoints'),
      consumePoints: number('consumePoints'),
    );
  }
}
