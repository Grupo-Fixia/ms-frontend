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
}
