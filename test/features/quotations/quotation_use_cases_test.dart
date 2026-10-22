import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/quotations/application/ports/quotation_repository.dart';
import 'package:ms_frontend/features/quotations/application/quotation_use_cases.dart';
import 'package:ms_frontend/features/quotations/domain/quotation.dart';
import 'package:ms_frontend/features/quotations/domain/quotation_exceptions.dart';

final _now = DateTime.utc(2026, 10, 22, 12);

Quotation _sent(NewQuotation q) => Quotation(
      id: 'q-1',
      serviceRequestId: q.serviceRequestId,
      providerId: 'p-1',
      amountInCents: q.amountInCents!,
      currency: q.currency,
      scope: q.scope,
      conditions: q.conditions,
      agreedAt: q.agreedAt!,
      validUntil: q.validUntil!,
      status: QuotationStatus.sent,
      statusName: 'Enviada',
    );

class _FakeRepository implements QuotationRepository {
  NewQuotation? sent;
  String? filter;
  String? requested;
  String? requestId;

  @override
  Future<Quotation> send(NewQuotation quotation) async {
    sent = quotation;
    return _sent(quotation);
  }

  @override
  Future<List<Quotation>> listMine({String? serviceRequestId}) async {
    filter = serviceRequestId;
    return const [];
  }

  @override
  Future<Quotation> getMine(String id) async {
    requested = id;
    return _sent(NewQuotation(
      serviceRequestId: 'r',
      amountInCents: 1,
      scope: 's',
      conditions: 'c',
      agreedAt: _now,
      validUntil: _now,
    ));
  }

  @override
  Future<List<Quotation>> listForRequest(String serviceRequestId) async {
    requestId = serviceRequestId;
    return const [];
  }
}

void main() {
  test('envía la cotización con los textos sin espacios sobrantes', () async {
    final repository = _FakeRepository();

    final saved = await SendQuotation(repository, now: () => _now)(
      NewQuotation(
        serviceRequestId: ' req-1 ',
        amountInCents: 15000050,
        scope: '  Cambio de tubería ',
        conditions: ' Pago contra entrega ',
        agreedAt: _now.add(const Duration(days: 3)),
        validUntil: _now.add(const Duration(days: 1)),
      ),
    );

    final sent = repository.sent!;
    expect(sent.serviceRequestId, 'req-1');
    expect(sent.scope, 'Cambio de tubería');
    expect(sent.conditions, 'Pago contra entrega');
    expect(sent.amountInCents, 15000050);
    expect(sent.currency, 'COP');
    expect(saved.status, QuotationStatus.sent);
  });

  test('no envía una cotización inválida', () async {
    final repository = _FakeRepository();

    await expectLater(
      SendQuotation(repository, now: () => _now)(
        const NewQuotation(
          serviceRequestId: '',
          amountInCents: null,
          scope: '',
          conditions: '',
          agreedAt: null,
          validUntil: null,
        ),
      ),
      throwsA(isA<QuotationFailure>()
          .having((f) => f.message, 'message', SendQuotation.invalidDataMessage)
          .having((f) => f.fieldErrors, 'fieldErrors', hasLength(6))),
    );
    expect(repository.sent, isNull);
  });

  test('por defecto usa la hora actual', () async {
    await expectLater(
      SendQuotation(_FakeRepository())(
        NewQuotation(
          serviceRequestId: 'r',
          amountInCents: 100,
          scope: 's',
          conditions: 'c',
          agreedAt: DateTime.now().subtract(const Duration(minutes: 1)),
          validUntil: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ),
      throwsA(isA<QuotationFailure>()),
    );
  });

  test('consultas del prestador y del cliente', () async {
    final repository = _FakeRepository();

    await ListMyQuotations(repository)(serviceRequestId: 'req-1');
    await GetMyQuotation(repository)('q-9');
    await ListRequestQuotations(repository)('req-2');

    expect(repository.filter, 'req-1');
    expect(repository.requested, 'q-9');
    expect(repository.requestId, 'req-2');
  });
}
