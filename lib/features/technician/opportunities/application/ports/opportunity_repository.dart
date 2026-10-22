import '../../domain/opportunity.dart';

/// Puerto de salida: oportunidades compatibles del técnico autenticado
/// (GC-340).
///
/// Lanza `OpportunityFailure` si el backend rechaza la consulta o no se
/// puede contactar.
abstract interface class OpportunityRepository {
  /// Una página, la más reciente primero. [cursor] es el `nextCursor` de la
  /// página anterior (o `null` para la primera).
  Future<OpportunityPage> fetchPage({required int limit, String? cursor});
}
