import '../../../core/network/network_api.dart';
import '../../../core/network/payment_exception.dart';
import '../../../shared/type/payment_type.dart';
import '../domain/mobile_payment.dart';

class PaymentRepository {
  const PaymentRepository(this.api);

  final NetworkApi api;

  Future<Map<String, Object?>> preview(PaymentProduct product) =>
      api.previewAppSubscription(product.id);

  Future<MobilePaymentOrder> create(
    PaymentProduct product,
    PaymentChannel channel,
  ) async {
    final data = await api.createAppPayment(
      kind: product.kind,
      channel: channel,
      productId: product.id,
    );
    final order = MobilePaymentOrder.fromJson(data, channel);
    if (order.tradeNo.isEmpty) {
      throw PaymentException(data: data);
    }
    return order;
  }

  Future<PaymentState> query(String tradeNo) async {
    final data = await api.appPaymentOrder(tradeNo);
    final state = PaymentState.fromJson(data);
    if (state.tradeNo != tradeNo ||
        state.payment.isEmpty ||
        state.fulfillment.isEmpty ||
        state.refund.isEmpty) {
      throw PaymentException(data: data);
    }
    return state;
  }
}
