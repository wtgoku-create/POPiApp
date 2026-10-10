/// An active campaign and its server-defined eligibility and display metadata.
class Activity {
  const Activity({
    required this.id,
    required this.name,
    this.type = '',
    this.description = '',
    this.coverUrl = '',
    this.tags = const [],
    this.memberLevels = const [],
    this.status = 1,
    this.startsAt,
    this.endsAt,
  });

  final int id;
  final String name;
  final String type;
  final String description;
  final String coverUrl;
  final List<ActivityTag> tags;
  final List<int> memberLevels;
  final int status;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get isBookCard => type.trim().toLowerCase() == 'book_card';

  bool isActiveAt(DateTime now) =>
      status == 1 &&
      (startsAt == null || !now.isBefore(startsAt!)) &&
      (endsAt == null || !now.isAfter(endsAt!));

  bool allowsMemberLevel(int level) =>
      memberLevels.isEmpty || memberLevels.contains(level);
}

class ActivityTag {
  const ActivityTag({required this.label, this.background, this.foreground});

  final String label;
  final int? background;
  final int? foreground;
}

class ActivityCatalog {
  const ActivityCatalog({
    required this.activities,
    this.memberLabels = const {},
  });

  final List<Activity> activities;
  final Map<int, String> memberLabels;
}
