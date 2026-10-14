import '../../../core/network/network_api.dart';
import '../domain/product_plan.dart';

class ProductPlanRepository {
  const ProductPlanRepository(this.networkApi);

  final NetworkApi networkApi;

  Future<List<ProductPlan>> fetchAll({String? planCategory}) async {
    return (await networkApi.productPlans(planCategory: planCategory))
        .whereType<Map>()
        .map((item) => ProductPlan.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
