import 'package:dio/dio.dart';

/// Saves the current profile through the shared studio role contract.
class RoleProfileApi {
  const RoleProfileApi(this.dio);

  final Dio dio;

  Future<void> save(String id, Map<String, Object?> profile) async {
    await dio.post<Map<String, dynamic>>(
      '/api_client/agent/v2/roles/${Uri.encodeComponent(id)}/save',
      data: {
        'clientRequestId':
            'mobile-role-profile-save-${DateTime.now().microsecondsSinceEpoch}',
        'profile': profile,
      },
    );
  }
}
