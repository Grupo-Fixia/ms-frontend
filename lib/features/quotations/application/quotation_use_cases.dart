import '../domain/quotation.dart';
import '../domain/quotation_exceptions.dart';
import '../domain/quotation_rules.dart';
import 'ports/quotation_repository.dart';

/// Caso de uso: crear y enviar una cotización al cliente (GC-300). Valida los
/// datos antes de enviarlos.
class SendQuotation {
  SendQuotation(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const invalidDataMessage = 'Revisa los datos marcados.';

  final QuotationRepository _repository;
  final DateTime Function() _now;

  Future<Quotation> call(NewQuotation quotation) async {
    final errors = QuotationRules.validate(quotation, now: _now());
    if (errors.isNotEmpty) {
      throw QuotationFailure(invalidDataMessage, fieldErrors: errors);
    }
    return _repository.send(
      NewQuotation(
        serviceRequestId: quotation.serviceRequestId.trim(),
        amountInCents: quotation.amountInCents,
        currency: quotation.currency,
        scope: quotation.scope.trim(),
        conditions: quotation.conditions.trim(),
        agreedAt: quotation.agreedAt,
        validUntil: quotation.validUntil,
      ),
    );
  }
}

/// Caso de uso: listar las cotizaciones del prestador (GC-300).
class ListMyQuotations {
  const ListMyQuotations(this._repository);

  final QuotationRepository _repository;

  Future<List<Quotation>> call({String? serviceRequestId}) =>
      _repository.listMine(serviceRequestId: serviceRequestId);
}

/// Caso de uso: consultar una cotización del prestador (GC-300).
class GetMyQuotation {
  const GetMyQuotation(this._repository);

  final QuotationRepository _repository;

  Future<Quotation> call(String id) => _repository.getMine(id);
}

/// Caso de uso: el cliente consulta las cotizaciones de su solicitud
/// (GC-300).
class ListRequestQuotations {
  const ListRequestQuotations(this._repository);

  final QuotationRepository _repository;

  Future<List<Quotation>> call(String serviceRequestId) =>
      _repository.listForRequest(serviceRequestId);
}

/// Caso de uso: el cliente acepta una cotización de su solicitud (GC-361).
///
/// Al aceptarla, la solicitud queda contratada con las condiciones de esa
/// cotización (GC-359). Solo se puede aceptar una cotización vigente del
/// prestador seleccionado; el backend rechaza las demás.
class AcceptQuotation {
  const AcceptQuotation(this._repository);

  final QuotationRepository _repository;

  Future<Quotation> call(String serviceRequestId, String quotationId) async =>
      _repository.accept(
        _required(serviceRequestId, _missingRequest),
        _required(quotationId, _missingQuotation),
      );
}

/// Caso de uso: el cliente rechaza una cotización de su solicitud (GC-361).
/// El prestador seleccionado puede enviar otra.
class RejectQuotation {
  const RejectQuotation(this._repository);

  final QuotationRepository _repository;

  Future<Quotation> call(String serviceRequestId, String quotationId) async =>
      _repository.reject(
        _required(serviceRequestId, _missingRequest),
        _required(quotationId, _missingQuotation),
      );
}

const _missingRequest = 'Falta la solicitud de la cotización.';
const _missingQuotation = 'Elige la cotización que quieres responder.';

String _required(String value, String message) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) throw QuotationFailure(message);
  return trimmed;
}
