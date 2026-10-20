import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../core/network/agent_api_exception.dart';
import '../../../core/utils/app_url.dart';
import '../../../shared/type/list_page.dart';
import '../../assets/domain/library_role.dart';
import '../../session/data/session_artifact_repository.dart';
import '../../session/domain/session_artifact.dart';
import '../domain/ip_account.dart';
import '../domain/ip_account_home.dart';
import '../domain/account_preferences.dart';

/// Account management, archives and bound-session creation history.
class IpAccountRepository {
  const IpAccountRepository(this._api, {NetworkAgentApi? agentApi})
    : _agentApi = agentApi;
  final NetworkApi _api;
  final NetworkAgentApi? _agentApi;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    } on FormatException {
      throw const ApiException();
    }
  }

  Future<ListPage<IpAccount>> list({
    String status = 'active',
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) => _request(() async {
    final data = await _api.ipAccountsPage(
      status: status,
      page: page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
    return ListPage.fromJson(
      data,
      page: page,
      pageSize: pageSize,
      parse: (item) => IpAccount(
        id: _id(item['id']),
        title: _title(item),
        description: _account(item).description,
        isPaused: item['status'] != 'active',
        iconBackgroundColor: item['iconBackgroundColor'] is String
            ? item['iconBackgroundColor'] as String
            : null,
      ),
    );
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
        return _account(account);
      });

  IpAccountHome _account(Map<String, dynamic> account) => IpAccountHome(
    id: _id(account['id']),
    title: _title(account),
    revision: account['revision'] as int? ?? 1,
    avatar: _avatar(account),
    iconBackgroundColor: account['iconBackgroundColor'] is String
        ? account['iconBackgroundColor'] as String
        : null,
    status: account['status'] as String? ?? 'active',
    preferences: Map<String, Object?>.from(
      account['preferences'] as Map? ?? const {},
    ),
    memoryMarkdown: account['memoryMarkdown'] as String? ?? '',
    userPrompt: account['userPrompt'] as String? ?? '',
    residentRoles: [
      for (final role in account['residentRoles'] as List? ?? const [])
        Map<String, Object?>.from(role as Map),
    ],
  );

  Future<List<AccountPreferenceStep>> preferenceOptions({
    CancelToken? cancelToken,
  }) => _request(() async {
    final data = await _api.ipAccountPreferenceOptions(
      cancelToken: cancelToken,
    );
    return [
      for (final step in data['steps'] as List)
        AccountPreferenceStep.fromJson(step as Map<String, dynamic>),
    ];
  });

  Future<String> create({
    required String requestId,
    String? title,
    Map<String, Object?>? preferences,
    String? userPrompt,
    CancelToken? cancelToken,
  }) => _request(() async {
    final result = await _api.createIpAccount(
      clientRequestId: requestId,
      title: title,
      preferences: preferences,
      userPrompt: userPrompt,
      cancelToken: cancelToken,
    );
    return result.$1;
  });

  Future<void> update(
    String id, {
    String? title,
    Map<String, Object?>? preferences,
    String? userPrompt,
    CancelToken? cancelToken,
  }) => _request(() async {
    await _api.updateIpAccount(
      id,
      title: title,
      preferences: preferences,
      userPrompt: userPrompt,
      cancelToken: cancelToken,
    );
  });

  Future<void> archive(String id, {CancelToken? cancelToken}) =>
      _request(() async {
        await _api.archiveIpAccount(id, cancelToken: cancelToken);
      });
  Future<void> restore(String id, {CancelToken? cancelToken}) =>
      _request(() async {
        await _api.updateIpAccount(
          id,
          action: 'restore',
          cancelToken: cancelToken,
        );
      });

  /// Account history comes from its bound session, including every output type.
  Future<ListPage<SessionArtifact>> creationHistory(
    String id, {
    String keyword = '',
    int page = 1,
    CancelToken? cancelToken,
  }) => _request(() async {
    final agentApi = _agentApi;
    if (agentApi == null) throw const ApiException();
    Map<String, dynamic> session;
    try {
      session = await agentApi.sessionByAccount(id, cancelToken: cancelToken);
    } on AgentApiException catch (error) {
      if (error.statusCode == 404 &&
          error.code == 'ACCOUNT_SESSION_NOT_FOUND') {
        return ListPage(items: const [], page: page, pageCount: 0);
      }
      rethrow;
    }
    final sessionId = _id(session['id']);
    final repository = ApiSessionArtifactRepository(
      _api,
      cancelToken: cancelToken,
    );
    return repository.page(sessionId, page: page, keyword: keyword);
  });

  Future<AccountArchivePage> archives(
    String id, {
    String keyword = '',
    int page = 1,
    CancelToken? cancelToken,
  }) => _request(() async {
    final data = await _api.ipAccountArchives(
      id,
      keyword: keyword,
      page: page,
      cancelToken: cancelToken,
    );
    final items = _items(data, page);
    final info = data['pageInfo'] as Map;
    return AccountArchivePage(
      items: [for (final item in items) _creation(item)],
      page: page,
      pageCount: info['pageCount'] as int,
      total: info['total'] as int? ?? items.length,
    );
  });

  Future<AccountCreationArchive> archiveDetail(
    String id,
    String creationId, {
    String? versionId,
    CancelToken? cancelToken,
  }) => _request(
    () async => AccountCreationArchive.fromJson(
      await _api.ipAccountArchiveDetail(
        id,
        creationId,
        versionId: versionId,
        cancelToken: cancelToken,
      ),
    ),
  );

  IpAccountCreation _creation(Map<String, dynamic> item) => IpAccountCreation(
    id: _id(item['id']),
    title: _title(item),
    versionId: item['versionId'] as String?,
    summary: item['summary'] as String? ?? '',
    sessionId: item['sessionId'] as String?,
  );

  Future<IpAccountResources> resources(
    IpAccountHome account, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) => _request(() async {
    final data = await _api.ipAccountArchives(
      account.id,
      page: page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
    final items = _items(data, page);
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
      page: page,
      pageCount: (data['pageInfo'] as Map)['pageCount'] as int,
      creations: [
        for (final item in items)
          if (item['status'] != 'archived') _creation(item),
      ],
      roles: roles,
    );
  });

  Future<ListPage<LibraryRole>> availableRoles(
    String category, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) => _request(() async {
    final data = await _api.listLibraryRoles(
      category: category,
      page: page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
    return ListPage<LibraryRole>.fromJson(
      data,
      page: page,
      pageSize: pageSize,
      parse: LibraryRole.fromJson,
    ).where((role) => role.canCreate);
  });

  Future<void> saveProfile(
    IpAccountHome account,
    Map<String, Object?> changes, {
    required String requestId,
    CancelToken? cancelToken,
  }) => _request(() async {
    await _api.updateIpAccount(
      account.id,
      preferences: changes,
      cancelToken: cancelToken,
    );
  });

  Future<void> rename(
    String id,
    String title, {
    required int revision,
    required String requestId,
    CancelToken? cancelToken,
  }) => _request(() async {
    await _api.updateIpAccount(
      id,
      title: title.trim(),
      cancelToken: cancelToken,
    );
  });

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

  List<Map<String, dynamic>> _items(Map<String, dynamic> result, int page) {
    final list = result['list'];
    final info = result['pageInfo'];
    if (list is! List ||
        info is! Map ||
        info['page'] != page ||
        info['pageCount'] is! int ||
        (info['pageCount'] as int) < 0 ||
        (info['pageCount'] as int) > 10000) {
      throw const ApiException();
    }
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) item else throw const ApiException(),
    ];
  }

  String _id(Object? value) {
    if (value == null || value.toString().isEmpty) throw const ApiException();
    return value.toString();
  }

  String _title(Map<String, dynamic> value) {
    if (value['title'] is! String) throw const ApiException();
    return value['title'] as String;
  }

  String _avatar(Map<String, dynamic> account) {
    final mainRole = account['mainRole'];
    for (final value in [
      account['avatar'],
      if (mainRole is Map) mainRole['avatar'],
    ]) {
      if (value is String && value.trim().isNotEmpty) {
        return AppUrl.resolve(value.trim());
      }
    }
    return '';
  }
}
