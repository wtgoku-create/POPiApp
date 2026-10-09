import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../../assets/domain/library_role.dart';
import '../domain/ip_account.dart';
import '../domain/ip_account_home.dart';

/// Reads account facts and saves new profile versions through the business API.
class IpAccountRepository {
  const IpAccountRepository(this._api);
  final NetworkApi _api;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<List<IpAccount>> list({CancelToken? cancelToken}) =>
      _request(() async {
        final items = await _pages(
          (page) => _api.projectsPage(page, cancelToken: cancelToken),
        );
        return [
          for (final item in items)
            IpAccount(
              id: _id(item['id']),
              title: _title(item),
              description: '',
              isPaused: item['status'] != 'active',
            ),
        ];
      });

  Future<IpAccountHome> detail(String id, {CancelToken? cancelToken}) =>
      _request(() async {
        final account = await _api.ipAccountDetail(
          id,
          cancelToken: cancelToken,
        );
        final revision = account['revision'];
        if (_id(account['id']) != id || revision is! int || revision < 1) {
          throw const ApiException();
        }
        Map<String, Object?> profile = const {};
        final activeId = account['activeProfileVersionId'];
        if (activeId != null) {
          // The newest draft can differ from the active profile. Match its ID.
          var found = false;
          for (var page = 1; !found; page++) {
            final result = await _api.ipAccountResourcesPage(
              id,
              profiles: true,
              page: page,
              cancelToken: cancelToken,
            );
            for (final item in _items(result, page)) {
              if (_id(item['id']) == _id(activeId)) {
                final value = item['profile'];
                if (value is! Map<String, dynamic>) throw const ApiException();
                profile = Map<String, Object?>.unmodifiable(value);
                found = true;
                break;
              }
            }
            if (!found && !_hasMore(result, page)) throw const ApiException();
          }
        }
        final roles = account['residentRoles'];
        if (roles != null && roles is! List) throw const ApiException();
        return IpAccountHome(
          id: id,
          title: _title(account),
          revision: revision,
          status: account['status'] as String? ?? 'active',
          profile: profile,
          residentRoles: [
            for (final role in roles as List? ?? const [])
              if (role is Map<String, dynamic>)
                Map<String, Object?>.unmodifiable(role)
              else
                throw const ApiException(),
          ],
        );
      });

  Future<IpAccountResources> resources(
    IpAccountHome account, {
    CancelToken? cancelToken,
  }) => _request(() async {
    final items = await _pages(
      (page) => _api.ipAccountResourcesPage(
        account.id,
        profiles: false,
        page: page,
        cancelToken: cancelToken,
      ),
    );
    final roles = <LibraryRole>[];
    for (final ref in account.residentRoles) {
      roles.add(
        LibraryRole.fromJson(
          await _api.libraryRoleDetail(
            _id(ref['roleId']),
            cancelToken: cancelToken,
          ),
        ),
      );
    }
    return IpAccountResources(
      creations: [
        for (final item in items)
          if (item['status'] != 'archived')
            IpAccountCreation(
              id: _id(item['id']),
              title: _title(item),
              sessionId: item['sessionId'] as String?,
            ),
      ],
      roles: roles,
    );
  });

  Future<List<LibraryRole>> availableRoles(
    String category, {
    CancelToken? cancelToken,
  }) => _request(() async {
    final items = await _pages(
      (page) => _api.listLibraryRoles(
        category: category,
        page: page,
        pageSize: 100,
        cancelToken: cancelToken,
      ),
    );
    return items
        .map(LibraryRole.fromJson)
        .where((role) => role.canCreate)
        .toList();
  });

  Future<void> saveProfile(
    IpAccountHome account,
    Map<String, Object?> changes, {
    required String requestId,
    CancelToken? cancelToken,
  }) => _request(
    () => _api.saveIpAccountProfile(
      account.id,
      revision: account.revision,
      clientRequestId: requestId,
      profile: {...account.profile, ...changes},
      cancelToken: cancelToken,
    ),
  );

  Future<void> rename(
    String id,
    String title, {
    required int revision,
    required String requestId,
    CancelToken? cancelToken,
  }) => _request(
    () => _api.updateProject(
      id,
      title: title.trim(),
      clientRequestId: requestId,
      expectedRevision: revision,
      cancelToken: cancelToken,
    ),
  );

  Future<void> saveRoles(
    IpAccountHome account,
    List<String> roleIds, {
    required String requestId,
    CancelToken? cancelToken,
  }) => _request(
    () => _api.saveIpAccountRoles(
      account.id,
      revision: account.revision,
      clientRequestId: requestId,
      items: [
        for (final id in roleIds)
          account.residentRoles.firstWhere(
            (ref) => _id(ref['roleId']) == id,
            orElse: () => {'roleId': int.parse(id)},
          ),
      ],
      cancelToken: cancelToken,
    ),
  );

  Future<List<Map<String, dynamic>>> _pages(
    Future<Map<String, dynamic>> Function(int) load,
  ) async {
    final items = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final result = await load(page);
      items.addAll(_items(result, page));
      if (!_hasMore(result, page)) return items;
    }
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> result, int page) {
    final list = result['list'];
    final info = result['pageInfo'];
    if (list is! List ||
        info is! Map ||
        info['page'] != page ||
        info['pageCount'] is! int ||
        (info['pageCount'] as int) < 1 ||
        (info['pageCount'] as int) > 10000) {
      throw const ApiException();
    }
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) item else throw const ApiException(),
    ];
  }

  bool _hasMore(Map<String, dynamic> result, int page) =>
      page < (result['pageInfo'] as Map)['pageCount'];
  String _id(Object? value) {
    if (value == null || value.toString().isEmpty) throw const ApiException();
    return value.toString();
  }

  String _title(Map<String, dynamic> value) {
    if (value['title'] is! String) throw const ApiException();
    return value['title'] as String;
  }
}
