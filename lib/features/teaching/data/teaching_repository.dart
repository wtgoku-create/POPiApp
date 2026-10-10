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
    final memberRequest = _optional(networkApi.memberLevels);
    final configRequest = _optional(networkApi.parameterConfig);
    final planRequest = _optional(
      () => ProductPlanRepository(networkApi).fetchAll(),
    );
    final members = await memberRequest;
    final config = await configRequest;
    final plans = await planRequest;
    final memberLabels = <int, String>{};
    final list = members?['list'];
    if (list is List) {
      for (final item in list.whereType<Map>()) {
        final level = _integer(item['memberLevel']);
        final name = _string(item['memberName']);
        if (item['deleted'] != true &&
            _integer(item['status']) == 1 &&
            name.isNotEmpty) {
          memberLabels[level] = name;
        }
      }
    }
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
