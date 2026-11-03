enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
  unknown;

  static PaymentStatus fromApi(Object? value) => switch (value) {
        'Pending' => pending,
        'Processing' => processing,
        'Completed' => completed,
        'Failed' => failed,
        'Refunded' => refunded,
        _ => unknown,
      };
}

class PaymentFailure implements Exception {
  const PaymentFailure(this.message,
      {this.isSessionExpired = false,
      this.isInsufficientBalance = false,
      this.statusCode});
  final String message;
  final bool isSessionExpired;
  final bool isInsufficientBalance;
  final int? statusCode;
  @override
  String toString() => message;
}

int moneyInCents(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > 90071992547409 ||
      (value * 100 - (value * 100).round()).abs() > 0.001) {
    throw const FormatException('Importe inválido');
  }
  return (value * 100).round();
}

String requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Falta $key');
  }
  return value;
}

class CommissionQuote {
  const CommissionQuote(
      {required this.priceCents,
      required this.commissionCents,
      required this.totalCents,
      required this.currency,
      required this.ruleId,
      required this.ruleValidFrom});
  factory CommissionQuote.fromJson(Map<String, dynamic> json) {
    final price = moneyInCents(json['price']);
    final commission = moneyInCents(json['commission']);
    final total = moneyInCents(json['total']);
    final rate = json['rate'];
    if (price <= 0 ||
        price + commission != total ||
        rate is! num ||
        !rate.isFinite ||
        rate < 0) {
      throw const FormatException('Desglose inválido');
    }
    return CommissionQuote(
        priceCents: price,
        commissionCents: commission,
        totalCents: total,
        currency: requiredText(json, 'currency'),
        ruleId: requiredText(json, 'ruleId'),
        ruleValidFrom: DateTime.parse(requiredText(json, 'ruleValidFrom')));
  }
  final int priceCents, commissionCents, totalCents;
  final String currency, ruleId;
  final DateTime ruleValidFrom;
  bool matches(int cents, String currency) =>
      priceCents == cents && this.currency == currency;
}

enum HoldStatus {
  notApplicable,
  pending,
  held,
  failed,
  captured,
  released,
  reversed,
  unknown;

  static HoldStatus fromApi(Object? value) => switch (value) {
        'NotApplicable' => notApplicable,
        'Pending' => pending,
        'Held' => held,
        'Failed' => failed,
        'Captured' => captured,
        'Released' => released,
        'Reversed' => reversed,
        _ => unknown,
      };

  String get label => switch (this) {
        notApplicable => 'Retención no aplicable',
        pending => 'Retención pendiente',
        held => 'Pago retenido',
        failed => 'Retención fallida',
        captured => 'Retención cobrada',
        released => 'Retención liberada',
        reversed => 'Pago revertido',
        unknown => 'Estado de retención no confirmado',
      };
}

class PaymentBreakdown {
  const PaymentBreakdown(
      {required this.priceCents,
      required this.commissionCents,
      required this.commissionRate,
      required this.totalCents});
  factory PaymentBreakdown.fromJson(Map<String, dynamic> json) {
    final price = moneyInCents(json['price']);
    final commission = moneyInCents(json['commission']);
    final total = moneyInCents(json['total']);
    final rate = json['commissionRate'];
    if (price <= 0 ||
        price + commission != total ||
        rate is! num ||
        !rate.isFinite ||
        rate < 0) {
      throw const FormatException('Desglose de pago inválido');
    }
    return PaymentBreakdown(
        priceCents: price,
        commissionCents: commission,
        totalCents: total,
        commissionRate: rate.toDouble());
  }
  final int priceCents, commissionCents, totalCents;
  final double commissionRate;
}

class ServicePayment {
  const ServicePayment(
      {required this.id,
      required this.serviceRequestId,
      required this.amountCents,
      required this.currency,
      required this.status,
      required this.method,
      this.isWalletPayment = false,
      this.holdStatus = HoldStatus.unknown,
      this.breakdown,
      bool canRetryHold = false,
      this.failureReason})
      : _canRetryHold = canRetryHold;
  factory ServicePayment.fromJson(Map<String, dynamic> json) {
    final amount = moneyInCents(json['amount']);
    final rawBreakdown = json['breakdown'];
    if (rawBreakdown != null && rawBreakdown is! Map<String, dynamic>) {
      throw const FormatException('Desglose de pago inválido');
    }
    final breakdown = rawBreakdown == null
        ? null
        : PaymentBreakdown.fromJson(rawBreakdown as Map<String, dynamic>);
    final isWallet = json['isWalletPayment'] == true;
    if (breakdown != null && (!isWallet || breakdown.totalCents != amount)) {
      throw const FormatException('El desglose no corresponde al pago');
    }
    return ServicePayment(
        id: requiredText(json, 'id'),
        serviceRequestId: requiredText(json, 'serviceRequestId'),
        amountCents: amount,
        currency: requiredText(json, 'currency'),
        status: PaymentStatus.fromApi(json['status']),
        method: requiredText(json, 'method'),
        isWalletPayment: isWallet,
        holdStatus: HoldStatus.fromApi(json['holdStatus']),
        breakdown: breakdown,
        canRetryHold: json['canRetryHold'] == true,
        failureReason: json['failureReason'] is String
            ? json['failureReason'] as String
            : null);
  }
  final String id, serviceRequestId, currency, method;
  final int amountCents;
  final PaymentStatus status;
  final String? failureReason;
  final bool isWalletPayment, _canRetryHold;
  final HoldStatus holdStatus;
  final PaymentBreakdown? breakdown;

  HoldStatus get confirmedHoldStatus {
    if (!isWalletPayment) {
      return holdStatus == HoldStatus.notApplicable
          ? holdStatus
          : HoldStatus.unknown;
    }
    final consistent = switch (holdStatus) {
      HoldStatus.pending => status == PaymentStatus.pending,
      HoldStatus.held => status == PaymentStatus.processing,
      HoldStatus.failed => status == PaymentStatus.failed,
      HoldStatus.captured => status == PaymentStatus.completed,
      HoldStatus.released ||
      HoldStatus.reversed =>
        status == PaymentStatus.refunded,
      _ => false,
    };
    return consistent ? holdStatus : HoldStatus.unknown;
  }

  bool get canRetryHold =>
      _canRetryHold &&
      isWalletPayment &&
      confirmedHoldStatus == HoldStatus.failed;
  String get label => switch (status) {
        PaymentStatus.pending => 'Pago pendiente',
        PaymentStatus.processing => 'Pago en procesamiento',
        PaymentStatus.completed => 'Pago completado',
        PaymentStatus.failed => 'Pago fallido',
        PaymentStatus.refunded => 'Pago reembolsado',
        PaymentStatus.unknown => 'Estado del pago no reconocido',
      };
}

class WalletBalance {
  const WalletBalance(
      {required this.availableCents,
      required this.heldCents,
      required this.currency});
  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
      availableCents: moneyInCents(json['availableBalance']),
      heldCents: moneyInCents(json['heldBalance']),
      currency: requiredText(json, 'currency'));
  final int availableCents, heldCents;
  final String currency;
}
