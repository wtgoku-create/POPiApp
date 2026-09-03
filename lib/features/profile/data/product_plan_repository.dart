import '../../../core/network/network_api.dart';
import '../domain/product_plan.dart';

class ProductPlanRepository {
  const ProductPlanRepository(this.networkApi);

  final NetworkApi networkApi;

  Future<List<ProductPlan>> fetchAll({int type = 1}) async {
    return (await networkApi.productPlans(type: type))
        .whereType<Map>()
        .map((item) => ProductPlan.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
