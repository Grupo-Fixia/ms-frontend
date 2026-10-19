import '../domain/service_request.dart';
import '../domain/service_request_exceptions.dart';
import '../domain/service_request_rules.dart';
import 'ports/service_request_repository.dart';

/// Caso de uso: publicar una solicitud de servicio (GC-296). Valida los datos
/// antes de enviarlos.
class PublishServiceRequest {
  PublishServiceRequest(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const invalidDataMessage = 'Revisa los datos marcados.';

  final ServiceRequestRepository _repository;
  final DateTime Function() _now;

  Future<ServiceRequest> call(NewServiceRequest request) async {
    final errors = ServiceRequestRules.validate(request, now: _now());
    if (errors.isNotEmpty) {
      throw ServiceRequestFailure(invalidDataMessage, fieldErrors: errors);
    }
    final approximate = request.approximateLocation;
    final exact = request.exactLocation;
    return _repository.publish(
      NewServiceRequest(
        category: request.category,
        description: request.description.trim(),
        approximateLocation: ApproximateLocation(
          city: approximate.city.trim(),
          zone: approximate.zone.trim(),
          latitude: approximate.latitude,
          longitude: approximate.longitude,
        ),
        expectedAt: request.expectedAt,
        exactLocation: exact == null
            ? null
            : ExactLocation(
                address: exact.address.trim(),
                latitude: exact.latitude,
                longitude: exact.longitude,
              ),
        photoKeys: List.unmodifiable(request.photoKeys),
      ),
    );
  }
}

/// Caso de uso: listar las solicitudes del cliente (GC-296).
class ListMyServiceRequests {
  const ListMyServiceRequests(this._repository);

  final ServiceRequestRepository _repository;

  Future<List<ServiceRequest>> call() => _repository.listMine();
}

/// Caso de uso: consultar una solicitud del cliente (GC-296).
class GetMyServiceRequest {
  const GetMyServiceRequest(this._repository);

  final ServiceRequestRepository _repository;

  Future<ServiceRequest> call(String id) => _repository.getMine(id);
}
