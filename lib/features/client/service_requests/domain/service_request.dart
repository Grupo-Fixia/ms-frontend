import '../../../../core/constants/service_category.dart';
import '../../../../core/constants/service_request_status.dart';
import '../../../../core/domain/service_budget.dart';

export '../../../../core/constants/service_request_status.dart';

/// Ubicación que ven los técnicos: ciudad, zona y, opcionalmente,
/// coordenadas aproximadas (el backend las redondea a dos decimales).
class ApproximateLocation {
  const ApproximateLocation({
    required this.city,
    required this.zone,
    this.latitude,
    this.longitude,
  });

  final String city;
  final String zone;
  final double? latitude;
  final double? longitude;
}

/// Dirección exacta: se guarda protegida y el backend solo la devuelve
/// cuando la solicitud está contratada.
class ExactLocation {
  const ExactLocation({required this.address, this.latitude, this.longitude});

  final String address;
  final double? latitude;
  final double? longitude;
}

/// Solicitud de servicio publicada por el cliente (GC-296, RF-013).
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.approximateLocation,
    required this.expectedAt,
    this.exactLocation,
    this.photoKeys = const [],
    this.selectedProviderId,
    this.publishedAt,
    this.updatedAt,
    this.budget,
  });

  final String id;
  final ServiceCategory category;
  final String description;
  final ServiceRequestStatus status;
  final ApproximateLocation approximateLocation;
  final DateTime expectedAt;
  final ExactLocation? exactLocation;
  final List<String> photoKeys;

  /// Solo presente desde que el cliente selecciona un prestador.
  final String? selectedProviderId;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  /// Null para solicitudes históricas o respuestas sin el nuevo contrato.
  final ServiceBudget? budget;
}

/// Datos que el cliente escribe para publicar una solicitud.
class NewServiceRequest {
  const NewServiceRequest({
    required this.category,
    required this.description,
    required this.approximateLocation,
    required this.expectedAt,
    this.exactLocation,
    this.photoKeys = const [],
    this.budget,
  });

  final ServiceCategory? category;
  final String description;
  final ApproximateLocation approximateLocation;
  final DateTime? expectedAt;
  final ExactLocation? exactLocation;
  final ServiceBudget? budget;

  /// Claves de fotos ya subidas al almacenamiento (la subida no es parte de
  /// la API de solicitudes).
  final List<String> photoKeys;
}
