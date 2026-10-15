/// Server pagination is retained even when business filters hide some rows.
class ListPage<T> {
  const ListPage({
    required this.items,
    required this.page,
    required this.pageCount,
  });

  final List<T> items;
  final int page;
  final int pageCount;
  bool get hasMore => page < pageCount;

  factory ListPage.fromJson(
    Map<String, Object?> data, {
    required int page,
    required int pageSize,
    required T Function(Map<String, dynamic>) parse,
  }) {
    final list = data['list'];
    final info = data['pageInfo'];
    if (list is! List ||
        info is! Map ||
        info['page'] != page ||
        info['pageCount'] is! int ||
        (info['pageCount'] as int) < 0 ||
        (info['pageCount'] as int) > 10000 ||
        list.length > pageSize ||
        (info['pageSize'] != null && info['pageSize'] != pageSize)) {
      throw const FormatException('Invalid list pagination');
    }
    return ListPage(
      items: List.unmodifiable([
        for (final item in list)
          if (item is Map<String, dynamic>)
            parse(item)
          else
            throw const FormatException('Invalid list item'),
      ]),
      page: page,
      pageCount: info['pageCount'] as int,
    );
  }

  ListPage<T> where(bool Function(T) test) => ListPage(
    items: items.where(test).toList(growable: false),
    page: page,
    pageCount: pageCount,
  );
}
