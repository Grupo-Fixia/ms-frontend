import '../../domain/quotation.dart';

/// Puerto de salida: respuesta del cliente a una cotización (GC-360).
///
/// El backend aún no expone estos endpoints; por ahora solo existe la
/// implementación en memoria.
abstract interface class QuotationDecisionRepository {
  /// Acepta la cotización enviada y vigente.
  Future<Quotation> accept(String quotationId);

  /// Rechaza la cotización enviada y vigente, con motivo opcional.
  Future<Quotation> reject(String quotationId, {String? reason});
}
