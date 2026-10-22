/// Estado de una cotización (`QuotationStatus` de ms-services).
enum QuotationStatus {
  sent('SENT', 'Enviada'),
  accepted('ACCEPTED', 'Aceptada'),
  rejected('REJECTED', 'Rechazada'),
  expired('EXPIRED', 'Vencida'),
  superseded('SUPERSEDED', 'Reemplazada');

  const QuotationStatus(this.apiValue, this.label);

  /// Valor exacto que usa el backend.
  final String apiValue;

  /// Texto que ve el usuario si el backend no envía `statusName`.
  final String label;

  /// Devuelve `null` si el backend envía un estado que el frontend no conoce.
  static QuotationStatus? fromApi(String? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}

/// Material que el prestador cobra aparte de la mano de obra.
class QuotationMaterial {
  const QuotationMaterial({required this.name, required this.amountInCents});

  final String name;
  final int amountInCents;
}

/// Cotización del prestador seleccionado para una solicitud (GC-300,
/// RF-017): valor, alcance, condiciones y fecha acordada.
///
/// El valor se guarda en centavos para no arrastrar errores de punto
/// flotante (el backend admite hasta dos decimales). [amountInCents] es el
/// total: mano de obra más [materials].
class Quotation {
  const Quotation({
    required this.id,
    required this.serviceRequestId,
    required this.providerId,
    required this.amountInCents,
    required this.currency,
    required this.scope,
    required this.conditions,
    required this.agreedAt,
    required this.validUntil,
    required this.status,
    required this.statusName,
    this.materials = const [],
    this.isExpired = false,
    this.rejectionReason,
    this.respondedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String serviceRequestId;
  final String providerId;
  final int amountInCents;
  final String currency;
  final String scope;
  final String conditions;
  final DateTime agreedAt;
  final DateTime validUntil;
  final QuotationStatus status;

  /// Nombre del estado en español, tal como lo envía el backend.
  final String statusName;

  /// Desglose de materiales; vacío si el backend no lo envía.
  final List<QuotationMaterial> materials;

  /// Sigue enviada pero su vigencia ya pasó: el cliente ya no puede
  /// aceptarla.
  final bool isExpired;

  /// Motivo opcional que escribió el cliente al rechazar.
  final String? rejectionReason;
  final DateTime? respondedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get materialsInCents =>
      materials.fold(0, (total, item) => total + item.amountInCents);

  /// Valor de la mano de obra: el total menos los materiales.
  int get laborInCents => amountInCents - materialsInCents;

  /// El cliente todavía puede responderla.
  bool get isOpen => status == QuotationStatus.sent && !isExpired;
}

/// Datos que el prestador escribe para enviar una cotización.
class NewQuotation {
  const NewQuotation({
    required this.serviceRequestId,
    required this.amountInCents,
    required this.scope,
    required this.conditions,
    required this.agreedAt,
    required this.validUntil,
    this.materials = const [],
    this.currency = 'COP',
  });

  final String serviceRequestId;

  /// Total (mano de obra más materiales). `null` si el texto del valor no se
  /// pudo leer (ver `QuotationRules.parseAmount`).
  final int? amountInCents;
  final String scope;
  final String conditions;
  final DateTime? agreedAt;
  final DateTime? validUntil;
  final List<QuotationMaterial> materials;
  final String currency;
}
