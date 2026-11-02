import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/contracts/application/ports/contract_repository.dart';
import 'package:ms_frontend/features/contracts/domain/contract_exceptions.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/quotations/application/ports/quotation_repository.dart';
import 'package:ms_frontend/features/quotations/domain/quotation.dart';
import 'package:ms_frontend/features/quotations/domain/quotation_exceptions.dart';

/// Cotizaciones en memoria con las reglas de ms-services: cada envío es una
/// versión nueva y la vigente anterior queda reemplazada; aceptar contrata.
class FakeQuotations implements QuotationRepository {
  FakeQuotations({this.contracts});

  final FakeContracts? contracts;
  final items = <Quotation>[];
  Object? acceptError;
  int sends = 0;

  Quotation _copy(Quotation q, QuotationStatus status, {bool? current}) =>
      Quotation(
        id: q.id,
        serviceRequestId: q.serviceRequestId,
        providerId: q.providerId,
        amountInCents: q.amountInCents,
        currency: q.currency,
        scope: q.scope,
        conditions: q.conditions,
        agreedAt: q.agreedAt,
        validUntil: q.validUntil,
        status: status,
        statusName: status.label,
        revision: q.revision,
        current: current ?? false,
        createdAt: q.createdAt,
      );

  void add(String requestId, int cents, {QuotationStatus? status}) {
    items.add(Quotation(
      id: 'q${items.length + 1}',
      serviceRequestId: requestId,
      providerId: 'prov-1',
      amountInCents: cents,
      currency: 'COP',
      scope: 'Cambio de sifón',
      conditions: 'Incluye materiales',
      agreedAt: DateTime.utc(2030, 1, 10, 14),
      validUntil: DateTime.utc(2030, 1, 9, 14),
      status: status ?? QuotationStatus.sent,
      statusName: (status ?? QuotationStatus.sent).label,
      revision: items.length + 1,
      current: (status ?? QuotationStatus.sent) == QuotationStatus.sent,
      createdAt: DateTime.utc(2029, 12, 1, 10 + items.length),
    ));
  }

  @override
  Future<Quotation> send(NewQuotation quotation) async {
    sends++;
    for (var i = 0; i < items.length; i++) {
      if (items[i].isCurrent) {
        items[i] = _copy(items[i], QuotationStatus.superseded);
      }
    }
    final sent = Quotation(
      id: 'q${items.length + 1}',
      serviceRequestId: quotation.serviceRequestId,
      providerId: 'prov-1',
      amountInCents: quotation.amountInCents!,
      currency: quotation.currency,
      scope: quotation.scope,
      conditions: quotation.conditions,
      agreedAt: quotation.agreedAt!,
      validUntil: quotation.validUntil!,
      status: QuotationStatus.sent,
      statusName: 'Enviada',
      revision: items.length + 1,
      current: true,
    );
    items.add(sent);
    return sent;
  }

  @override
  Future<List<Quotation>> listMine({String? serviceRequestId}) async =>
      List.of(items.reversed);

  @override
  Future<Quotation> getMine(String id) async =>
      items.firstWhere((q) => q.id == id);

  @override
  Future<List<Quotation>> listForRequest(String serviceRequestId) async =>
      List.of(items.reversed);

  @override
  Future<Quotation> accept(String serviceRequestId, String quotationId) async {
    final error = acceptError;
    if (error != null) throw error;
    final i = items.indexWhere((q) => q.id == quotationId);
    if (i < 0 || !items[i].isCurrent) {
      throw const QuotationFailure('Esa cotización ya no se puede aceptar.');
    }
    items[i] = _copy(items[i], QuotationStatus.accepted);
    contracts?.contractFrom(items[i]);
    return items[i];
  }

  @override
  Future<Quotation> reject(String serviceRequestId, String quotationId) async {
    final i = items.indexWhere((q) => q.id == quotationId);
    items[i] = _copy(items[i], QuotationStatus.rejected);
    return items[i];
  }
}

class FakeContracts implements ContractRepository {
  final items = <ServiceContract>[];

  void contractFrom(Quotation q, {ServiceRequestStatus? status}) {
    items.add(ServiceContract(
      id: 'c${items.length + 1}',
      serviceRequestId: q.serviceRequestId,
      quotationId: q.id,
      clientId: 'cli-1',
      providerId: q.providerId,
      amountInCents: q.amountInCents,
      currency: q.currency,
      scope: q.scope,
      conditions: q.conditions,
      agreedAt: q.agreedAt,
      contractedAt: DateTime.utc(2029, 12, 2),
      request: const ContractedRequest(
        category: ServiceCategory.plumbing,
        description: 'Fuga en la cocina',
        city: 'Bogotá',
        zone: 'Chapinero',
        exactAddress: 'Calle 45 # 13-20',
      ),
      serviceStatus: status ?? ServiceRequestStatus.contracted,
      timeline: [
        ContractTransition(
          fromStatus: ServiceRequestStatus.providerSelected,
          toStatus: ServiceRequestStatus.contracted,
          actor: TransitionActor.client,
          occurredAt: DateTime.utc(2029, 12, 2),
        ),
      ],
    ));
  }

  @override
  Future<ServiceContract> getForRequest(String serviceRequestId) async {
    for (final c in items) {
      if (c.serviceRequestId == serviceRequestId) return c;
    }
    throw const ContractFailure('Esta solicitud aún no está contratada.',
        isNotFound: true);
  }

  @override
  Future<List<ServiceContract>> listMine() async => List.of(items);

  @override
  Future<ServiceContract> getMine(String id) async =>
      items.firstWhere((c) => c.id == id);
}
