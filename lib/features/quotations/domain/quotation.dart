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

/// Cotización del prestador seleccionado para una solicitud (GC-300,
/// RF-017): valor, alcance, condiciones y fecha acordada.
///
/// El valor se guarda en centavos para no arrastrar errores de punto
/// flotante (el backend admite hasta dos decimales).
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
    this.isExpired = false,
    this.revision,
    this.current,
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

  /// Sigue enviada pero su vigencia ya pasó: el cliente ya no puede
  /// aceptarla.
  final bool isExpired;

  /// Versión dentro de la solicitud (GC-427): 1 es la primera cotización y
  /// cada ajuste suma uno. `null` si el backend no la envía.
  final int? revision;

  /// El backend la marca como la versión vigente: sigue enviada y no ha
  /// vencido (GC-427). `null` si el backend no lo envía.
  final bool? current;
  final DateTime? respondedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// El cliente todavía puede responderla.
  bool get isOpen => status == QuotationStatus.sent && !isExpired;

  /// Versión vigente según el servidor; si no lo dice, la que sigue abierta.
  bool get isCurrent => current ?? isOpen;

  /// «Versión 2», o «Cotización» si no hay número.
  String get versionLabel =>
      revision == null ? 'Cotización' : 'Versión $revision';
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
    this.currency = 'COP',
  });

  final String serviceRequestId;

  /// `null` si el texto del valor no se pudo leer (ver
  /// `QuotationRules.parseAmount`).
  final int? amountInCents;
  final String scope;
  final String conditions;
  final DateTime? agreedAt;
  final DateTime? validUntil;
  final String currency;
}
