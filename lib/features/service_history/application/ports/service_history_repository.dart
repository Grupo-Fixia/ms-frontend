import '../../domain/service_evaluation.dart';
import '../../domain/service_history_entry.dart';

/// Puerto de salida: historial propio de servicios contratados (GC-449, API
/// de GC-448 en ms-services). Quien consulta y su rol salen del token.
abstract interface class ServiceHistoryRepository {
  /// Una página, del servicio más reciente al más antiguo. [cursor] es el
  /// `nextCursor` de la página anterior; `null` pide la primera.
  Future<ServiceHistoryResult> listPage({String? cursor, int limit});
}

/// Puerto de salida: evaluaciones de servicios en las que quien consulta
/// evaluó o fue evaluado (GC-449, GC-445; API de GC-444 en ms-users).
abstract interface class ServiceEvaluationRepository {
  /// Evaluaciones de esos servicios; lista vacía si no hay ninguna.
  Future<List<ServiceEvaluation>> listFor(List<String> serviceRequestIds);

  /// Registra la calificación de quien consulta a su contraparte (GC-445) y
  /// devuelve la evaluación guardada. Un reintento idéntico devuelve la
  /// misma evaluación sin duplicarla.
  Future<ServiceEvaluation> submit(NewServiceEvaluation evaluation);
}
