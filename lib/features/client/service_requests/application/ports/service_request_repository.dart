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
}
