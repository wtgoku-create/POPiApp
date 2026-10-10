/// Course metadata shared by the catalog and its navigation targets.
class TeachingCategory {
  const TeachingCategory({required this.id, required this.name});

  final int id;
  final String name;
}

class TeachingCourse {
  const TeachingCourse({
    required this.id,
    required this.name,
    this.coverUrl = '',
    this.instructorName = '',
    this.instructorAvatarUrl = '',
    this.memberLevels = const [],
    this.tag = '',
  });

  final int id;
  final String name;
  final String coverUrl;
  final String instructorName;
  final String instructorAvatarUrl;
  final List<int> memberLevels;
  final String tag;

  int? lowestKnownMemberLevel(Map<int, String> labels) {
    for (final level in memberLevels) {
      if (labels.containsKey(level)) return level;
    }
    return null;
  }
}

class TeachingCourseList {
  const TeachingCourseList({required this.items, required this.hasMore});

  final List<TeachingCourse> items;
  final bool hasMore;
}

class TeachingHighlights {
  const TeachingHighlights({
    this.communityQrUrl = '',
    this.memberLabels = const {},
    this.startingPrice,
  });

  final String communityQrUrl;
  final Map<int, String> memberLabels;
  final String? startingPrice;
}
