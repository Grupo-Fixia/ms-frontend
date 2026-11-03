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

/// Caso de uso: el técnico inicia el servicio contratado (GC-437).
class StartService {
  const StartService(this._repository);

  final ContractRepository _repository;

  Future<ServiceContract> call(String contractId) => _repository
      .start(_required(contractId, GetMyContract.missingContractMessage));
}

/// Caso de uso: el técnico declara que terminó el trabajo (GC-442, API de
/// GC-441). El servicio no queda cerrado hasta que el cliente lo confirme.
class FinishService {
  const FinishService(this._repository);

  final ContractRepository _repository;

  Future<ServiceContract> call(String contractId) => _repository
      .finish(_required(contractId, GetMyContract.missingContractMessage));
}

/// Caso de uso: el cliente confirma el cierre del servicio (GC-442).
class ConfirmServiceClosure {
  const ConfirmServiceClosure(this._repository);

  final ContractRepository _repository;

  Future<ServiceContract> call(String serviceRequestId) =>
      _repository.confirmClosure(_required(
          serviceRequestId, GetRequestContract.missingRequestMessage));
}

/// Caso de uso: el cliente no está conforme y devuelve el servicio a
/// ejecución con un motivo (GC-442). Nunca cierra el servicio.
class ObjectServiceClosure {
  const ObjectServiceClosure(this._repository);

  static const missingReasonMessage = 'Cuéntale al técnico qué falta.';
  static const reasonMaxLength = 500;
  static const tooLongMessage =
      'El motivo no puede superar $reasonMaxLength caracteres.';

  final ContractRepository _repository;

  Future<ServiceContract> call(String serviceRequestId, String reason) {
    final text = reason.trim();
    if (text.isEmpty) throw const ContractFailure(missingReasonMessage);
    if (text.length > reasonMaxLength) {
      throw const ContractFailure(tooLongMessage);
    }
    return _repository.objectClosure(
        _required(serviceRequestId, GetRequestContract.missingRequestMessage),
        text);
  }
}

String _required(String value, String message) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) throw ContractFailure(message);
  return trimmed;
}
