import '../domain/contract_exceptions.dart';
import '../domain/service_contract.dart';
import 'ports/contract_repository.dart';

/// Caso de uso: el cliente consulta la contratación de su solicitud, después
/// de aceptar una cotización (GC-361).
class GetRequestContract {
  const GetRequestContract(this._repository);

  static const missingRequestMessage = 'Falta la solicitud contratada.';

  final ContractRepository _repository;

  Future<ServiceContract> call(String serviceRequestId) async {
    final id = serviceRequestId.trim();
    if (id.isEmpty) throw const ContractFailure(missingRequestMessage);
    return _repository.getForRequest(id);
  }
}

/// Caso de uso: el prestador consulta sus contrataciones (GC-361).
class ListMyContracts {
  const ListMyContracts(this._repository);

  final ContractRepository _repository;

  Future<List<ServiceContract>> call() => _repository.listMine();
}

/// Caso de uso: el prestador consulta una contratación, con la dirección
/// exacta del servicio (GC-361).
class GetMyContract {
  const GetMyContract(this._repository);

  static const missingContractMessage = 'Elige la contratación.';

  final ContractRepository _repository;

  Future<ServiceContract> call(String id) async {
    final contractId = id.trim();
    if (contractId.isEmpty) throw const ContractFailure(missingContractMessage);
    return _repository.getMine(contractId);
  }
}
