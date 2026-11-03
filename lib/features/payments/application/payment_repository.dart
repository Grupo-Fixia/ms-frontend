import '../domain/payment.dart';

abstract interface class PaymentRepository {
  Future<CommissionQuote> quote(int amountCents, String currency);
  Future<ServicePayment?> forRequest(String serviceRequestId);
  Future<WalletBalance> wallet();
  Future<ServicePayment> retryHold(ServicePayment payment);
}
