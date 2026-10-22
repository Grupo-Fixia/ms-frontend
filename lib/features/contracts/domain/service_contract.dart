import '../../../core/constants/service_category.dart';

/// Contratación formalizada al aceptar una cotización (GC-359, GC-361): lo
/// acordado, copiado de la cotización aceptada, y un resumen de la
/// solicitud. Como la solicitud ya está contratada, el resumen trae la
/// dirección exacta si el cliente la dio: es lo que recibe el prestador.
///
/// No hay datos de contacto ni de pago: el pago ocurre fuera de Fixia.
class ServiceContract {
  const ServiceContract({
    required this.id,
    required this.serviceRequestId,
    required this.quotationId,
    required this.clientId,
    required this.providerId,
    required this.amountInCents,
    required this.currency,
    required this.scope,
    required this.conditions,
    required this.agreedAt,
    required this.contractedAt,
    required this.request,
  });

  final String id;
  final String serviceRequestId;
  final String quotationId;
  final String clientId;
  final String providerId;

  /// En centavos, para no perder precisión con decimales.
  final int amountInCents;
  final String currency;
  final String scope;
  final String conditions;

  /// Fecha y hora acordadas para el servicio.
  final DateTime agreedAt;
  final DateTime contractedAt;
  final ContractedRequest request;
}

/// Resumen de la solicitud contratada.
class ContractedRequest {
  const ContractedRequest({
    required this.category,
    required this.description,
    required this.city,
    required this.zone,
    this.exactAddress,
    this.expectedAt,
  });

  final ServiceCategory category;
  final String description;
  final String city;
  final String zone;

  /// Solo si el cliente la dio al publicar.
  final String? exactAddress;
  final DateTime? expectedAt;
}
