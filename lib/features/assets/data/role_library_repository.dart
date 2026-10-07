import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_api.dart';
import '../../../shared/providers/network_provider.dart';
import '../domain/library_role.dart';
import 'role_profile_api.dart';

typedef RoleProfileSaver =
    Future<LibraryRole> Function(String id, Map<String, Object?> profile);

final roleProfileSaverProvider = Provider<RoleProfileSaver>((ref) {
  final dio = ref.watch(dioProvider);
  final api = RoleProfileApi(dio);
  final details = NetworkApi(dio);
  return (id, profile) async {
    await api.save(id, profile);
    return LibraryRole.fromJson(await details.libraryRoleDetail(id));
  };
});

final roleDetailLoaderProvider = Provider<Future<LibraryRole> Function(String)>(
  (ref) {
    final api = NetworkApi(ref.watch(dioProvider));
    return (id) async => LibraryRole.fromJson(await api.libraryRoleDetail(id));
  },
);

final roleDeleteProvider = Provider<Future<void> Function(String)>((ref) {
  final api = NetworkApi(ref.watch(dioProvider));
  return (id) => api.deleteLibraryRole(
    id,
    'mobile-role-delete-${DateTime.now().microsecondsSinceEpoch}',
  );
});

typedef RolePageLoader =
    Future<LibraryRolePage> Function({
      required String category,
      required int page,
      required int pageSize,
    });

final rolePageLoaderProvider = Provider<RolePageLoader>((ref) {
  final api = NetworkApi(ref.watch(dioProvider));
  return ({required category, required page, required pageSize}) async =>
      LibraryRolePage.fromJson(
        await api.listLibraryRoles(
          category: category,
          page: page,
          pageSize: pageSize,
        ),
      );
});
