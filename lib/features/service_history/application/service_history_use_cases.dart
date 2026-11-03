import '../domain/service_evaluation.dart';
import '../domain/service_history_entry.dart';
import 'ports/service_history_repository.dart';

/// Caso de uso: consultar una página del historial propio (GC-449).
class ListServiceHistory {
  const ListServiceHistory(this._repository);

  static const pageSize = 20;

  final ServiceHistoryRepository _repository;

  Future<ServiceHistoryResult> call({String? cursor}) =>
      _repository.listPage(cursor: cursor, limit: pageSize);
}

/// Caso de uso: evaluaciones de los servicios del historial (GC-449). Pide
/// en tandas de 50, el máximo que acepta ms-users, y no consulta si no hay
/// servicios.
class GetServiceEvaluations {
  const GetServiceEvaluations(this._repository);

  static const maxIdsPerRequest = 50;

  final ServiceEvaluationRepository _repository;

  Future<List<ServiceEvaluation>> call(
      Iterable<String> serviceRequestIds) async {
    final ids = serviceRequestIds.toSet().toList();
    final evaluations = <ServiceEvaluation>[];
    for (var start = 0; start < ids.length; start += maxIdsPerRequest) {
      final end = start + maxIdsPerRequest > ids.length
          ? ids.length
          : start + maxIdsPerRequest;
      evaluations.addAll(await _repository.listFor(ids.sublist(start, end)));
    }
    return List.unmodifiable(evaluations);
  }
}
