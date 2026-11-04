import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/technician/applications/domain/proposed_price.dart';

void main() {
  test('precio único COP positivo sin pérdida de decimales', () {
    expect(ProposedPrice.currency, 'COP');
    expect(ProposedPrice.tryParse(' 00150000,50 ')?.amount, '150000.5');
    expect(ProposedPrice.tryParse('0,01')?.amount, '0.01');
    expect(ProposedPrice.tryParse('0,001'), isNull);
    expect(ProposedPrice.tryParse('150000.000'), isNull);
    expect(ProposedPrice.tryParse(List.filled(100, '9').join())?.amount,
        List.filled(100, '9').join());
  });
  test('rechaza ausente, cero, negativo, rango, texto y separadores ambiguos',
      () {
    for (final value in [
      '',
      '0',
      '00,00',
      '-1',
      '10-20',
      'COP 100',
      '1e5',
      '1.000.000',
      '1,000.50',
      'NaN',
      'Infinity'
    ]) {
      expect(ProposedPrice.tryParse(value), isNull, reason: value);
      expect(ProposedPrice.validate(value), isNotNull, reason: value);
    }
  });
}
