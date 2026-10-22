import '../../domain/applicant.dart';
import '../../domain/service_request.dart';

/// Puerto de salida: solicitudes de servicio del cliente autenticado
/// (GC-335).
///
/// Todos los métodos lanzan `ServiceRequestFailure` si el backend rechaza la
/// solicitud o no se puede contactar.
abstract interface class ServiceRequestRepository {
  /// Publica la solicitud y la devuelve con su id y estado `published`.
  Future<ServiceRequest> publish(NewServiceRequest request);

  /// Solicitudes del cliente, la más reciente primero.
  Future<List<ServiceRequest>> listMine();

  Future<ServiceRequest> getMine(String id);

  /// Postulantes de una solicitud del cliente, en orden de llegada (GC-351).
  Future<List<Applicant>> listApplicants(String requestId);

  /// Elige al prestador de la postulación [applicationId] (GC-351). Devuelve
  /// la solicitud en `providerSelected`; las demás postulaciones quedan
  /// rechazadas.
  Future<ServiceRequest> selectProvider(String requestId, String applicationId);
}
