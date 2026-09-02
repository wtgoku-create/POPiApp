class UserPointsLogPage {
  const UserPointsLogPage({
    required this.page,
    required this.pageSize,
    required this.pageCount,
    required this.total,
    required this.items,
  });

  final int page;
  final int pageSize;
  final int pageCount;
  final int total;
  final List<UserPointsLogEntry> items;

  bool get hasMore => page < pageCount;

  factory UserPointsLogPage.fromJson(Map<String, dynamic> json) {
    final rawPageInfo = json['pageInfo'] ?? json;
    if (rawPageInfo is! Map) {
      throw const FormatException('Missing points log pageInfo');
    }
    final pageInfo = Map<String, dynamic>.from(rawPageInfo);

    int number(String key) => _integer(pageInfo[key]);
    final list = json['list'] ?? pageInfo['list'];

    return UserPointsLogPage(
      page: number('page'),
      pageSize: number('pageSize'),
      pageCount: number('pageCount'),
      total: number('total'),
      items: list is List
          ? list
              .whereType<Map>()
              .map(
                (item) => UserPointsLogEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class UserPointsLogEntry {
  const UserPointsLogEntry({
    required this.id,
    required this.userId,
    required this.userCode,
    required this.userName,
    required this.points,
    required this.changeType,
    required this.sourceType,
    required this.sourceId,
    required this.content,
    required this.beforePoints,
    required this.afterPoints,
    required this.status,
    required this.createTime,
  });

  final int id;
  final int userId;
  final String userCode;
  final String userName;
  final int points;
  final int changeType;
  final String sourceType;
  final String sourceId;
  final String content;
  final int beforePoints;
  final int afterPoints;
  final int status;
  final DateTime? createTime;

  factory UserPointsLogEntry.fromJson(Map<String, dynamic> json) {
    int number(String key) => _integer(json[key]);
    String text(String key) => json[key]?.toString() ?? '';
    final createTime = json['createTime']?.toString();

    return UserPointsLogEntry(
      id: number('id'),
      userId: number('userId'),
      userCode: text('userCode'),
      userName: text('userName'),
      points: number('points'),
      changeType: number('changeType'),
      sourceType: text('sourceType'),
      sourceId: text('sourceId'),
      content: text('content'),
      beforePoints: number('beforePoints'),
      afterPoints: number('afterPoints'),
      status: number('status'),
      createTime: createTime == null || createTime.isEmpty
          ? null
          : DateTime.tryParse(createTime),
    );
  }
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
