import 'package:popi_ai_app/shared/type/list_page.dart';
export 'package:popi_ai_app/shared/type/list_page.dart';

ListPage<T> fixturePage<T>(List<T> items, {int page = 1, int pageSize = 20}) =>
    ListPage(
      items: items.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageCount: (items.length / pageSize).ceil().clamp(1, 10000),
    );
