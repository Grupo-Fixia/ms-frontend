import '../../domain/service_contract.dart';

/// Puerto de salida: contrataciones (GC-361, API de GC-359).
///
/// Todos los métodos lanzan `ContractFailure` si el backend rechaza la
/// consulta o no se puede contactar.
abstract interface class ContractRepository {
  /// La contratación de una solicitud del cliente autenticado.
  Future<ServiceContract> getForRequest(String serviceRequestId);

  /// Contrataciones del prestador autenticado, la más reciente primero.
  Future<List<ServiceContract>> listMine();

  /// Una contratación del prestador autenticado.
  Future<ServiceContract> getMine(String id);

  /// El técnico contratado inicia el servicio: `contracted` → `inProgress`
  /// (GC-437).
  Future<ServiceContract> start(String contractId);

  /// El técnico declara terminado el trabajo: `inProgress` →
  /// `technicianFinished` (GC-441). No cierra el servicio.
  Future<ServiceContract> finish(String contractId);

  /// El cliente confirma el cierre: `technicianFinished` → `closed`.
  Future<ServiceContract> confirmClosure(String serviceRequestId);

  /// El cliente objeta con un motivo: el servicio vuelve a `inProgress`.
  Future<ServiceContract> objectClosure(String serviceRequestId, String reason);
}
