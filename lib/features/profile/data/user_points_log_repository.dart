import '../../../core/network/network_api.dart';
import '../domain/user_points_log.dart';

class UserPointsLogRepository {
  const UserPointsLogRepository(this.networkApi);

  final NetworkApi networkApi;

  Future<UserPointsLogPage> fetchPage({
    required int page,
    required int pageSize,
  }) async {
    return UserPointsLogPage.fromJson(
      await networkApi.userPointsLog(page: page, pageSize: pageSize),
    );
  }
}
