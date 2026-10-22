import '../domain/application_exceptions.dart';
import '../domain/service_application.dart';
import 'ports/application_repository.dart';

/// Caso de uso: postularse a una solicitud disponible (GC-298).
class ApplyToServiceRequest {
  const ApplyToServiceRequest(this._repository);

  static const missingRequestMessage =
      'Elige la solicitud a la que te postulas.';

  final ApplicationRepository _repository;

  Future<ServiceApplication> call(String serviceRequestId) async {
    final id = serviceRequestId.trim();
    if (id.isEmpty) {
      throw const ApplicationFailure(
        missingRequestMessage,
        fieldErrors: {'serviceRequestId': missingRequestMessage},
      );
    }
    return _repository.apply(id);
  }
}

/// Caso de uso: listar las postulaciones del técnico (GC-298).
class ListMyApplications {
  const ListMyApplications(this._repository);

  final ApplicationRepository _repository;

  Future<List<ServiceApplication>> call() => _repository.listMine();
}

/// Caso de uso: consultar una postulación del técnico (GC-298).
class GetMyApplication {
  const GetMyApplication(this._repository);

  final ApplicationRepository _repository;

  Future<ServiceApplication> call(String id) => _repository.getMine(id);
}
