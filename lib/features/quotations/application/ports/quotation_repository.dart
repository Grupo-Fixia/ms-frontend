import '../../domain/quotation.dart';

/// Puerto de salida: cotizaciones (GC-356). Las del prestador las usa el
/// técnico; las de una solicitud, el cliente dueño.
///
/// Todos los métodos lanzan `QuotationFailure` si el backend rechaza la
/// solicitud o no se puede contactar.
abstract interface class QuotationRepository {
  /// Envía la cotización (queda `sent`; la anterior enviada queda
  /// reemplazada). Solo el prestador seleccionado de la solicitud.
  Future<Quotation> send(NewQuotation quotation);

  /// Cotizaciones del prestador, la más reciente primero; opcionalmente solo
  /// las de una solicitud.
  Future<List<Quotation>> listMine({String? serviceRequestId});

  Future<Quotation> getMine(String id);

  /// Cotizaciones que recibió el cliente en su solicitud, la más reciente
  /// primero.
  Future<List<Quotation>> listForRequest(String serviceRequestId);

  /// El cliente acepta la cotización (GC-361): queda `accepted` y la
  /// solicitud queda contratada. Repetirlo devuelve lo mismo.
  Future<Quotation> accept(String serviceRequestId, String quotationId);

  /// El cliente rechaza la cotización (GC-361): queda `rejected` y el
  /// prestador puede enviar otra. Repetirlo devuelve lo mismo.
  Future<Quotation> reject(String serviceRequestId, String quotationId);
}
