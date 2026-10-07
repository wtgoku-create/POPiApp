/// A Studio account displayed as an IP project in the navigation drawer.
class Project {
  const Project({required this.id, required this.title});

  final String id;
  final String title;

  factory Project.fromJson(Map<String, dynamic> json) =>
      Project(id: json['id'] as String, title: json['title'] as String);
}

class ProjectSession {
  const ProjectSession({
    required this.id,
    required this.title,
    this.archived = false,
    this.pinnedAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final bool archived;
  final DateTime? pinnedAt;
  final DateTime? updatedAt;

  factory ProjectSession.fromJson(Map<String, dynamic> json) => ProjectSession(
    id: json['id'] as String,
    title: json['title'] as String,
    archived: json['archived'] as bool? ?? false,
    pinnedAt: DateTime.tryParse(json['pinnedAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

typedef ProjectSessionSelection = ({String projectId, ProjectSession session});
