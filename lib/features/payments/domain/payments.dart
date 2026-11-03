import 'dart:math';

/// Pagos con billetera simulada (GC-476): ms-payments retiene el total al
/// contratar y, al confirmar el cierre, le paga el precio al prestador y la
/// comisión a Fixia. Todo el dinero es virtual.

/// Valores en pesos como los entrega ms-payments (decimal). Se guardan en
/// centavos para no arrastrar errores de redondeo.
int pesosToCents(num value) => moneyInCents(value);

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

class PaymentsFailure implements Exception {
  const PaymentsFailure(this.message,
      {this.isSessionExpired = false,
      this.statusCode,
      this.isInsufficientBalance = false});

  final String message;
  final bool isSessionExpired;
  final int? statusCode;
  final bool isInsufficientBalance;

  @override
  String toString() => message;
}

class Wallet {
  const Wallet({
    required this.availableCents,
    required this.heldCents,
    this.currency = 'COP',
  });

  final int availableCents;
  final int heldCents;
  final String currency;
}

enum WalletEntryType {
  topUp('TopUp', 'Recarga', 1),
  withdrawal('Withdrawal', 'Retiro', -1),
  hold('Hold', 'Retenido por un servicio', -1),
  release('Release', 'Retención liberada', 1),
  capture('Capture', 'Pago de un servicio', 0),
  credit('Credit', 'Pago recibido por un servicio', 1),
  commission('Commission', 'Comisión de Fixia', 1),
  refund('Refund', 'Reembolso', 1),
  reversal('Reversal', 'Reverso de un pago', -1);

  const WalletEntryType(this.apiValue, this.label, this.sign);

  final String apiValue;
  final String label;

  /// Efecto en el saldo disponible: 1 suma, -1 resta, 0 solo mueve lo
  /// retenido (el cobro sale de lo que ya estaba retenido).
  final int sign;

  static WalletEntryType? fromApi(Object? value) {
    for (final t in values) {
      if (t.apiValue == value) return t;
    }
    return null;
  }
}

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.availableAfterCents,
    required this.heldAfterCents,
    required this.createdAt,
    this.reference,
  });

  final String id;
  final WalletEntryType type;
  final int amountCents;
  final int availableAfterCents;
  final int heldAfterCents;
  final DateTime createdAt;
  final String? reference;
}

class WalletEntriesPage {
  const WalletEntriesPage({required this.items, this.nextCursor});

  final List<WalletEntry> items;
  final String? nextCursor;
}

/// Desglose antes de aceptar una cotización (GC-491).
class CommissionQuote {
  const CommissionQuote({
    required this.priceCents,
    required this.commissionCents,
    required this.totalCents,
    required this.rate,
    this.ruleId,
    this.ruleValidFrom,
    this.currency = 'COP',
  });

  factory CommissionQuote.fromJson(Map<String, dynamic> json) {
    final price = moneyInCents(json['price']);
    final commission = moneyInCents(json['commission']);
    final total = moneyInCents(json['total']);
    final rate = json['rate'];
    if (price <= 0 ||
        price + commission != total ||
        rate is! num ||
        !rate.isFinite ||
        rate < 0 ||
        rate >= 1) {
      throw const FormatException('Desglose inválido');
    }
    return CommissionQuote(
        priceCents: price,
        commissionCents: commission,
        totalCents: total,
        rate: rate.toDouble(),
        currency: requiredText(json, 'currency'),
        ruleId: requiredText(json, 'ruleId'),
        ruleValidFrom: DateTime.parse(requiredText(json, 'ruleValidFrom')));
  }
  bool matches(int cents, String currency) =>
      priceCents == cents && this.currency == currency;
  final String? ruleId;
  final DateTime? ruleValidFrom;
  final int priceCents;
  final int commissionCents;
  final int totalCents;

  /// 0.15 = 15 %.
  final double rate;
  final String currency;

  String get ratePercent {
    final percent = rate * 100;
    return percent == percent.roundToDouble()
        ? '${percent.round()} %'
        : '${percent.toStringAsFixed(1)} %';
  }
}

/// Estado de la retención del pago de un servicio en la billetera.
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

class PaymentAmounts {
  const PaymentAmounts(
      {required this.priceCents,
      required this.commissionCents,
      required this.commissionRate,
      required this.totalCents});
  factory PaymentAmounts.fromJson(Map<String, dynamic> json) {
    final price = moneyInCents(json['price']);
    final commission = moneyInCents(json['commission']);
    final total = moneyInCents(json['total']);
    final rate = json['commissionRate'];
    if (price <= 0 ||
        price + commission != total ||
        rate is! num ||
        !rate.isFinite ||
        rate < 0 ||
        rate >= 1) {
      throw const FormatException('Desglose de pago inválido');
    }
    return PaymentAmounts(
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
      int? amountCents,
      int? totalCents,
      this.priceCents,
      this.commissionCents,
      this.rate,
      this.currency = 'COP',
      this.status = PaymentStatus.unknown,
      this.method = '',
      this.isWalletPayment = false,
      this.holdStatus = HoldStatus.unknown,
      this.breakdown,
      bool canRetryHold = false,
      this.failureReason})
      : amountCents = amountCents ?? totalCents ?? 0,
        _canRetryHold = canRetryHold;
  factory ServicePayment.fromJson(Map<String, dynamic> json) {
    final amount = moneyInCents(json['amount']);
    final rawBreakdown = json['breakdown'];
    if (rawBreakdown != null && rawBreakdown is! Map<String, dynamic>) {
      throw const FormatException('Desglose de pago inválido');
    }
    final breakdown = rawBreakdown == null
        ? null
        : PaymentAmounts.fromJson(rawBreakdown as Map<String, dynamic>);
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
        priceCents: breakdown?.priceCents,
        commissionCents: breakdown?.commissionCents,
        rate: breakdown?.commissionRate,
        canRetryHold: json['canRetryHold'] == true,
        failureReason: json['failureReason'] is String
            ? json['failureReason'] as String
            : null);
  }
  final String id, serviceRequestId, currency, method;
  final int amountCents;
  final int? priceCents, commissionCents;
  final double? rate;
  int get totalCents => amountCents;
  final PaymentStatus status;
  final String? failureReason;
  final bool isWalletPayment, _canRetryHold;
  final HoldStatus holdStatus;
  final PaymentAmounts? breakdown;

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

/// Clave de idempotencia nueva por operación (UUID v4).
String newIdempotencyKey([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
