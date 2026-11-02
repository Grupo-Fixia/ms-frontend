import '../../../core/constants/service_category.dart';
import '../../../core/constants/service_request_status.dart';

export '../../../core/constants/service_request_status.dart';

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
    this.serviceStatus,
    this.timeline = const [],
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

  /// Estado actual del servicio (GC-437, GC-441). `null` si el backend no lo
  /// envía o es uno que el frontend no conoce.
  final ServiceRequestStatus? serviceStatus;

  /// Historial de cambios de estado, del más antiguo al más reciente. Vacío
  /// en los listados.
  final List<ContractTransition> timeline;
}

/// Quién hizo un cambio de estado del servicio.
enum TransitionActor {
  client('CLIENT', 'Cliente'),
  professional('PROFESSIONAL', 'Técnico'),
  system('SYSTEM', 'Fixia');

  const TransitionActor(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TransitionActor? fromApi(String? value) {
    for (final actor in values) {
      if (actor.apiValue == value) return actor;
    }
    return null;
  }
}

/// Un cambio de estado del servicio, con el motivo si lo hubo (por ejemplo,
/// la objeción del cliente al cierre).
class ContractTransition {
  const ContractTransition({
    required this.toStatus,
    required this.occurredAt,
    this.fromStatus,
    this.actor,
    this.reason,
  });

  final ServiceRequestStatus? fromStatus;
  final ServiceRequestStatus toStatus;
  final TransitionActor? actor;
  final String? reason;
  final DateTime occurredAt;
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
