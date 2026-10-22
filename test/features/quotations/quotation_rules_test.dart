import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/quotations/domain/quotation.dart';
import 'package:ms_frontend/features/quotations/domain/quotation_exceptions.dart';
import 'package:ms_frontend/features/quotations/domain/quotation_rules.dart';

final _now = DateTime.utc(2026, 10, 22, 12);

NewQuotation _quotation({
  String requestId = 'req-1',
  int? amount = 15000000,
  String currency = 'COP',
  String scope = 'Cambio de tubería',
  String conditions = 'Pago contra entrega',
  DateTime? agreedAt,
  DateTime? validUntil,
  bool noDates = false,
}) =>
    NewQuotation(
      serviceRequestId: requestId,
      amountInCents: amount,
      currency: currency,
      scope: scope,
      conditions: conditions,
      agreedAt: noDates ? null : agreedAt ?? _now.add(const Duration(days: 3)),
      validUntil:
          noDates ? null : validUntil ?? _now.add(const Duration(days: 1)),
    );

Map<String, String> _validate(NewQuotation q) =>
    QuotationRules.validate(q, now: _now);

void main() {
  group('parseAmount', () {
    test('acepta enteros y hasta dos decimales con punto o coma', () {
      expect(QuotationRules.parseAmount('150000'), 15000000);
      expect(QuotationRules.parseAmount(' 150000.5 '), 15000050);
      expect(QuotationRules.parseAmount('150000,75'), 15000075);
      expect(QuotationRules.parseAmount('0.01'), 1);
      expect(QuotationRules.parseAmount('9999999999.99'),
          QuotationRules.maxAmountInCents);
    });

    test('rechaza lo que no es un valor válido', () {
      for (final text in [
        '',
        'abc',
        '150.000,50',
        '1.234',
        '-5',
        '10.',
        '12345678901',
      ]) {
        expect(QuotationRules.parseAmount(text), isNull, reason: text);
      }
    });
  });

  test('una cotización completa es válida', () {
    expect(_validate(_quotation()), isEmpty);
  });

  test('la vigencia puede ser igual a la fecha acordada', () {
    final date = _now.add(const Duration(days: 2));
    expect(_validate(_quotation(agreedAt: date, validUntil: date)), isEmpty);
  });

  test('todos los obligatorios', () {
    final errors = _validate(_quotation(
      requestId: ' ',
      amount: null,
      scope: '',
      conditions: '  ',
      noDates: true,
    ));

    expect(errors.keys, {
      'serviceRequestId',
      'amount',
      'scope',
      'conditions',
      'agreedAt',
      'validUntil',
    });
  });

  test('el valor debe ser positivo y caber en 10 dígitos', () {
    expect(_validate(_quotation(amount: 0))['amount'], contains('mayor'));
    expect(
      _validate(
          _quotation(amount: QuotationRules.maxAmountInCents + 1))['amount'],
      contains('10'),
    );
  });

  test('solo pesos colombianos', () {
    expect(_validate(_quotation(currency: 'USD')), contains('currency'));
  });

  test('textos de máximo 2000 caracteres', () {
    final errors =
        _validate(_quotation(scope: 'a' * 2001, conditions: 'b' * 2001));
    expect(errors['scope'], contains('2000'));
    expect(errors['conditions'], contains('2000'));
  });

  test('fechas posteriores a ahora y vigencia no posterior a la acordada', () {
    expect(_validate(_quotation(agreedAt: _now)), contains('agreedAt'));
    expect(_validate(_quotation(validUntil: _now)), contains('validUntil'));
    expect(
      _validate(_quotation(
        agreedAt: _now.add(const Duration(days: 1)),
        validUntil: _now.add(const Duration(days: 2)),
      ))['validUntil'],
      contains('posterior a la fecha acordada'),
    );
  });

  test('estados del backend', () {
    expect(QuotationStatus.fromApi('SUPERSEDED'), QuotationStatus.superseded);
    expect(QuotationStatus.fromApi('NUEVO'), isNull);
    expect(QuotationStatus.accepted.label, 'Aceptada');
  });

  test('una cotización enviada y vigente está abierta', () {
    Quotation q(QuotationStatus status, {bool expired = false}) => Quotation(
          id: 'q',
          serviceRequestId: 'r',
          providerId: 'p',
          amountInCents: 100,
          currency: 'COP',
          scope: 's',
          conditions: 'c',
          agreedAt: _now,
          validUntil: _now,
          status: status,
          statusName: status.label,
          isExpired: expired,
        );

    expect(q(QuotationStatus.sent).isOpen, isTrue);
    expect(q(QuotationStatus.sent, expired: true).isOpen, isFalse);
    expect(q(QuotationStatus.accepted).isOpen, isFalse);
  });

  test('la falla se muestra con su mensaje', () {
    expect(const QuotationFailure('Mensaje').toString(), 'Mensaje');
  });
}
