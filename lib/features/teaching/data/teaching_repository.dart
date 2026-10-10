import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../../profile/data/product_plan_repository.dart';
import '../domain/teaching.dart';

/// Uses the same category, pagination and membership rules as the Web catalog.
class TeachingRepository {
  const TeachingRepository(this.networkApi);

  final NetworkApi networkApi;

  Future<List<TeachingCategory>> fetchCategories() async {
    final records = (await networkApi.teachingCategories())
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .where(
          (item) =>
              _integer(item['id']) > 0 &&
              _integer(item['status']) == 1 &&
              item['deleted'] != true &&
              _string(item['code']).isNotEmpty &&
              _string(item['name']).isNotEmpty,
        )
        .toList();
    records.sort(_compareSort);
    return [
      for (final item in records)
        TeachingCategory(id: _integer(item['id']), name: _string(item['name'])),
    ];
  }

  Future<TeachingCourseList> fetchCourses({
    required int page,
    int pageSize = 20,
    int? categoryId,
    String? keyword,
  }) async {
    final data = await networkApi.teachingCourses(
      page: page,
      pageSize: pageSize,
      categoryId: categoryId,
      keyword: keyword,
    );
    final rawList = data['list'];
    if (rawList is! List) throw const ApiException();
    final records = rawList
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .where(
          (item) =>
              _integer(item['id']) > 0 &&
              item['deleted'] != true &&
              (item['status'] == null || _integer(item['status']) == 1),
        )
        .toList();
    records.sort(_compareSort);
    final pageInfo = data['pageInfo'];
    final pageCount = pageInfo is Map ? _integer(pageInfo['pageCount']) : 0;
    return TeachingCourseList(
      items: [for (final item in records) _course(item)],
      hasMore: pageCount > 0 ? page < pageCount : rawList.length >= pageSize,
    );
  }

  Future<TeachingHighlights> fetchHighlights() async {
    // A missing promotion or configuration must not block course browsing.
    final memberRequest = _optional(fetchMemberLabels);
    final configRequest = _optional(networkApi.parameterConfig);
    final planRequest = _optional(
      () => ProductPlanRepository(networkApi).fetchAll(),
    );
    final memberLabels = await memberRequest ?? <int, String>{};
    final config = await configRequest;
    final plans = await planRequest;
    final systemConfig = config?['systemConfig'];
    final validPlans = (plans ?? [])
        .where((plan) => !plan.deleted && plan.status == 1 && plan.price > 0)
        .toList();
    final monthly = validPlans
        .where((plan) => plan.planCategory == 'monthly')
        .toList();
    final prices =
        (monthly.isNotEmpty ? monthly : validPlans)
            .map((plan) => plan.price)
            .toList()
          ..sort();
    final price = prices.isEmpty ? null : prices.first / 100;
    return TeachingHighlights(
      memberLabels: memberLabels,
      communityQrUrl: systemConfig is Map
          ? _mediaUrl(systemConfig['popiSocialGroup'])
          : '',
      startingPrice: price == null
          ? null
          : price == price.roundToDouble()
          ? price.toInt().toString()
          : price.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), ''),
    );
  }

  Future<Map<int, String>> fetchMemberLabels() async {
    final data = await networkApi.memberLevels();
    final list = data['list'];
    return {
      if (list is List)
        for (final item in list.whereType<Map>())
          if (item['deleted'] != true &&
              _integer(item['status']) == 1 &&
              _string(item['memberName']).isNotEmpty)
            _integer(item['memberLevel']): _string(item['memberName']),
    };
  }

  /// Match Web's first-document selection without reordering the server list.
  Future<TeachingDocument?> fetchCourseDocument(int courseId) async {
    if (courseId <= 0) throw const ApiException();
    final list = (await networkApi.teachingDocuments(courseId))['list'];
    if (list is! List) throw const ApiException();
    if (list.isEmpty) return null;
    final first = list.first;
    if (first is! Map || _integer(first['id']) <= 0) {
      throw const ApiException();
    }
    final data = await networkApi.teachingDocumentDetail(_integer(first['id']));
    if (_integer(data['id']) <= 0 ||
        data['deleted'] == true ||
        (data['status'] != null && _integer(data['status']) != 1)) {
      throw const ApiException();
    }
    final user = data['userInfo'];
    final rawLevels = data['memberLevels'];
    final levels = rawLevels is List
        ? rawLevels
              .map((value) => int.tryParse(value.toString()))
              .whereType<int>()
              .where((value) => value >= 0)
              .toSet()
              .toList()
        : <int>[];
    levels.sort();
    final rawTags = data['tags'];
    final html =
        [
              data['contentHtml'],
              data['content'],
              data['html'],
              data['body'],
              data['documentContent'],
            ]
            .whereType<String>()
            .where((text) => text.trim().isNotEmpty)
            .firstOrNull ??
        '';
    return TeachingDocument(
      id: _integer(data['id']),
      title:
          [data['title'], data['name'], data['documentTitle']]
              .whereType<String>()
              .map((text) => text.trim())
              .where((text) => text.isNotEmpty)
              .firstOrNull ??
          '',
      contentJson:
          data['contentJson'] ??
          data['content'] ??
          data['documentContent'] ??
          data['body'] ??
          data['html'],
      contentHtml: html,
      canViewPaidContent: data['canViewPaidContent'] == true,
      publishTime: _string(data['publishTime']).isNotEmpty
          ? _string(data['publishTime'])
          : _string(data['createTime']),
      tags: rawTags is List
          ? rawTags
                .whereType<String>()
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList()
          : const [],
      memberLevels: levels,
      instructorName: user is Map ? _string(user['name']) : '',
      instructorAvatarUrl: user is Map ? _mediaUrl(user['avatar']) : '',
    );
  }

  TeachingCourse _course(Map<String, Object?> json) {
    final user = json['userInfo'];
    final levels = json['memberLevels'];
    final memberLevels = levels is List
        ? levels
              .map((value) => int.tryParse(value.toString()))
              .whereType<int>()
              .toSet()
              .toList()
        : <int>[];
    memberLevels.sort();
    final tags = json['tags'];
    return TeachingCourse(
      id: _integer(json['id']),
      name: _string(json['name']),
      description: _string(json['desp']),
      coverUrl: _mediaUrl(json['cover']),
      instructorName: user is Map ? _string(user['name']) : '',
      instructorAvatarUrl: user is Map ? _mediaUrl(user['avatar']) : '',
      memberLevels: memberLevels,
      tag: tags is List
          ? tags.map(_string).where((tag) => tag.isNotEmpty).firstOrNull ?? ''
          : '',
    );
  }

  String _mediaUrl(Object? value) {
    final text = _string(value);
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri == null) return '';
    final resolved = Uri.parse(networkApi.mediaBaseUrl).resolveUri(uri);
    return (resolved.scheme == 'https' || resolved.scheme == 'http') &&
            resolved.host.isNotEmpty
        ? resolved.toString()
        : '';
  }
}

Future<T?> _optional<T>(Future<T> Function() load) async {
  try {
    return await load();
  } catch (_) {
    return null;
  }
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

String _string(Object? value) => value?.toString().trim() ?? '';

int _compareSort(Map<String, Object?> a, Map<String, Object?> b) {
  final order = _integer(a['sort']).compareTo(_integer(b['sort']));
  return order == 0 ? _integer(a['id']).compareTo(_integer(b['id'])) : order;
}
