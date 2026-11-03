import 'dart:math';

/// Pagos con billetera simulada (GC-476): ms-payments retiene el total al
/// contratar y, al confirmar el cierre, le paga el precio al prestador y la
/// comisión a Fixia. Todo el dinero es virtual.

/// Valores en pesos como los entrega ms-payments (decimal). Se guardan en
/// centavos para no arrastrar errores de redondeo.
int pesosToCents(num value) => (value * 100).round();

class PaymentsFailure implements Exception {
  const PaymentsFailure(this.message, {this.isSessionExpired = false});

  final String message;
  final bool isSessionExpired;

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
    this.currency = 'COP',
  });

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
enum HoldStatus {
  notApplicable('NotApplicable', 'Sin pago con billetera'),
  pending('Pending', 'Pago pendiente'),
  held('Held', 'Dinero retenido'),
  failed('Failed', 'Falta saldo'),
  captured('Captured', 'Pagado'),
  released('Released', 'Retención liberada'),
  reversed('Reversed', 'Pago revertido');

  const HoldStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static HoldStatus fromApi(Object? value) {
    for (final s in values) {
      if (s.apiValue == value) return s;
    }
    return HoldStatus.notApplicable;
  }
}

/// Pago de un servicio contratado (GC-484, GC-485).
class ServicePayment {
  const ServicePayment({
    required this.id,
    required this.serviceRequestId,
    required this.holdStatus,
    required this.canRetryHold,
    this.priceCents,
    this.commissionCents,
    this.totalCents,
    this.rate,
    this.failureReason,
    this.currency = 'COP',
  });

  final String id;
  final String serviceRequestId;
  final HoldStatus holdStatus;

  /// Solo el cliente que paga puede reintentar la retención.
  final bool canRetryHold;
  final int? priceCents;
  final int? commissionCents;
  final int? totalCents;
  final double? rate;
  final String? failureReason;
  final String currency;
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
