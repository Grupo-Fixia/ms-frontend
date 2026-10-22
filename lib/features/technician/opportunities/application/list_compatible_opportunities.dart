import '../domain/opportunity.dart';
import 'ports/opportunity_repository.dart';

/// Caso de uso: consultar las solicitudes compatibles del técnico (GC-297).
///
/// El backend revisa un número limitado de candidatas por consulta, así que
/// una página puede llegar vacía y aun así tener más páginas. Para que la
/// vista no muestre "no hay oportunidades" cuando sí las hay, se piden
/// páginas seguidas hasta reunir al menos una o hasta que no queden más
/// (con un tope de [maxPagesPerCall] páginas por llamada).
class ListCompatibleOpportunities {
  const ListCompatibleOpportunities(
    this._repository, {
    this.maxPagesPerCall = 5,
  });

  static const defaultLimit = 20;
  static const maxLimit = 50;

  final OpportunityRepository _repository;
  final int maxPagesPerCall;

  /// [cursor] `null` pide desde el principio; para la siguiente página se
  /// pasa el `nextCursor` del resultado anterior. [limit] se ajusta a 1–50.
  Future<OpportunityPage> call({
    String? cursor,
    int limit = defaultLimit,
  }) async {
    final pageSize = limit.clamp(1, maxLimit);
    final items = <Opportunity>[];
    var next = cursor;
    for (var page = 0; page < maxPagesPerCall; page++) {
      final result = await _repository.fetchPage(
        limit: pageSize - items.length,
        cursor: next,
      );
      items.addAll(result.items);
      next = result.nextCursor;
      if (items.isNotEmpty || next == null) break;
    }
    return OpportunityPage(items: List.unmodifiable(items), nextCursor: next);
  }
}
