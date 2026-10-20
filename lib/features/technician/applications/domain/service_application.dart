import '../../../../core/constants/service_category.dart';
import '../../../../core/constants/application_status.dart';
import '../../../../core/constants/service_request_status.dart';

export '../../../../core/constants/application_status.dart';

/// Resumen de la solicitud a la que se postuló el técnico. Solo trae la
/// ubicación aproximada: la exacta no se comparte con los postulantes.
class ApplicationRequestSummary {
  const ApplicationRequestSummary({
    required this.id,
    required this.category,
    required this.city,
    required this.zone,
    this.status,
    this.latitude,
    this.longitude,
    this.expectedAt,
  });

  final String id;
  final ServiceCategory category;
  final String city;
  final String zone;

  /// `null` si el backend envía un estado que el frontend no conoce.
  final ServiceRequestStatus? status;
  final double? latitude;
  final double? longitude;
  final DateTime? expectedAt;
}

/// Postulación del técnico a una solicitud de servicio (GC-298, RF-015).
class ServiceApplication {
  const ServiceApplication({
    required this.id,
    required this.status,
    required this.serviceRequest,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ApplicationStatus status;
  final ApplicationRequestSummary serviceRequest;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
