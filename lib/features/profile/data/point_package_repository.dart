import '../../../core/network/network_api.dart';
import '../domain/point_package.dart';

class PointPackageRepository {
  const PointPackageRepository(this.networkApi);

  final NetworkApi networkApi;

  Future<List<PointPackage>> fetchAll() async {
    final packages = (await networkApi.pointPackages())
        .whereType<Map>()
        .map(
          (item) => PointPackage.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((package) => package.enabled)
        .toList();
    packages.sort((left, right) {
      final byOrder = left.sortOrder.compareTo(right.sortOrder);
      return byOrder != 0 ? byOrder : left.id.compareTo(right.id);
    });
    return packages;
  }
}
