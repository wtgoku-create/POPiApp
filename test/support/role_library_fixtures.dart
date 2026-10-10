import 'package:dio/dio.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';

typedef RolePageLoader =
    Future<LibraryRolePage> Function({
      required String category,
      required int page,
      required int pageSize,
    });
typedef RoleProfileSaver =
    Future<LibraryRole> Function(String id, Map<String, Object?> profile);

/// Supplies role HTTP responses for widget tests and the standalone preview.
Dio roleLibraryDio({
  RolePageLoader? loadPage,
  Future<LibraryRole> Function(String)? loadDetail,
  Future<void> Function(String)? delete,
  RoleProfileSaver? save,
}) {
  final dio = Dio();
  LibraryRole? savedRole;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) async {
        try {
          final Map<String, Object?> data;
          if (request.path == '/api_client/agent/v2/roles') {
            final page = request.queryParameters['page'] as int;
            final result = loadPage == null
                ? LibraryRolePage(items: const [], page: page, pageCount: 1)
                : await loadPage(
                    category: request.queryParameters['category'] as String,
                    page: page,
                    pageSize: request.queryParameters['pageSize'] as int,
                  );
            data = {
              'list': result.items.map(_roleJson).toList(),
              'pageInfo': {'page': result.page, 'pageCount': result.pageCount},
            };
          } else if (request.path.startsWith('/api_client/agent/v2/roles/')) {
            final id = Uri.decodeComponent(request.path.split('/')[5]);
            if (request.method == 'DELETE') {
              await delete?.call(id);
              data = {};
            } else if (request.method == 'POST' &&
                request.path.endsWith('/save')) {
              savedRole = await save!(
                id,
                Map<String, Object?>.from(request.data['profile'] as Map),
              );
              data = {};
            } else {
              final role = savedRole?.id == id
                  ? savedRole!
                  : await loadDetail!(id);
              data = _roleJson(role);
            }
          } else {
            throw StateError('Unexpected fixture request: ${request.path}');
          }
          handler.resolve(
            Response(
              requestOptions: request,
              data: {'status': '0000', 'data': data},
            ),
          );
        } catch (error, stackTrace) {
          handler.reject(
            DioException(
              requestOptions: request,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        }
      },
    ),
  );
  return dio;
}

Map<String, Object?> _roleJson(LibraryRole role) => {
  'id': role.id,
  'title': role.title,
  'description': role.description,
  'avatar': role.avatar,
  'profile': role.profile,
  'canEdit': role.canEdit,
  'canUseText': role.canCreate,
  'isCertified': role.isCertified,
  'profileComplete': role.profileComplete,
  if (role.profileVersion != null)
    'profileVersion': {'version': role.profileVersion},
};
