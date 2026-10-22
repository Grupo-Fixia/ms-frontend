import '../domain/quotation.dart';
import '../domain/quotation_exceptions.dart';
import '../domain/quotation_rules.dart';
import 'ports/quotation_decision_repository.dart';
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
        materials: quotation.materials,
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

/// Caso de uso: el cliente acepta la cotización recibida (GC-360).
class AcceptQuotation {
  const AcceptQuotation(this._repository);

  final QuotationDecisionRepository _repository;

  Future<Quotation> call(String quotationId) => _repository.accept(quotationId);
}

/// Caso de uso: el cliente rechaza la cotización recibida (GC-360).
class RejectQuotation {
  const RejectQuotation(this._repository);

  final QuotationDecisionRepository _repository;

  Future<Quotation> call(String quotationId, {String? reason}) {
    final trimmed = reason?.trim();
    return _repository.reject(
      quotationId,
      reason: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }
}
