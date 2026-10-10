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
    this.description = '',
  });

  final int id;
  final String name;
  final String coverUrl;
  final String instructorName;
  final String instructorAvatarUrl;
  final List<int> memberLevels;
  final String tag;
  final String description;

  int? lowestKnownMemberLevel(Map<int, String> labels) {
    for (final level in memberLevels) {
      if (labels.containsKey(level)) return level;
    }
    return null;
  }
}

/// Only public document fields cross the WebView bridge; app credentials stay native.
class TeachingDocument {
  const TeachingDocument({
    required this.id,
    this.title = '',
    this.contentJson,
    this.contentHtml = '',
    this.canViewPaidContent = false,
    this.publishTime = '',
    this.tags = const [],
    this.memberLevels = const [],
    this.instructorName = '',
    this.instructorAvatarUrl = '',
  });

  final int id;
  final String title;
  final Object? contentJson;
  final String contentHtml;
  final bool canViewPaidContent;
  final String publishTime;
  final List<String> tags;
  final List<int> memberLevels;
  final String instructorName;
  final String instructorAvatarUrl;

  Map<String, Object?> toReaderData() => {
    'id': id,
    'title': title,
    'contentJson': contentJson,
    'contentHtml': contentHtml,
    'canViewPaidContent': canViewPaidContent,
    'publishTime': publishTime,
    'tags': tags,
    'userInfo': {'name': instructorName, 'avatar': instructorAvatarUrl},
  };
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
