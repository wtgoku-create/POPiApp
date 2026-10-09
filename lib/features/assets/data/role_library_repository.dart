import '../../../core/network/network_api.dart';
import '../domain/library_role.dart';

/// Loads role data on demand without retaining page state or cached results.
class RoleLibraryRepository {
  const RoleLibraryRepository(this._api);

  final NetworkApi _api;

  Future<LibraryRolePage> fetchPage({
    required String category,
    required int page,
    required int pageSize,
  }) async => LibraryRolePage.fromJson(
    await _api.listLibraryRoles(
      category: category,
      page: page,
      pageSize: pageSize,
    ),
  );

  Future<LibraryRole> fetchDetail(String id) async =>
      LibraryRole.fromJson(await _api.libraryRoleDetail(id));

  Future<void> delete(String id) => _api.deleteLibraryRole(
    id,
    'mobile-role-delete-${DateTime.now().microsecondsSinceEpoch}',
  );

  Future<LibraryRole> saveProfile(
    String id,
    Map<String, Object?> profile,
  ) async {
    await _api.saveLibraryRoleProfile(
      id,
      profile,
      clientRequestId:
          'mobile-role-profile-save-${DateTime.now().microsecondsSinceEpoch}',
    );
    return fetchDetail(id);
  }
}
