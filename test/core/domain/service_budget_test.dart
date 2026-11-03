import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';

void main() {
  test('el presupuesto es obligatorio y estrictamente positivo', () {
    expect(ServiceBudget.validate(null), isNotNull);
    for (final input in ['', ' ', '0', '000', '0,00', '-1', '-0.01']) {
      expect(ServiceBudget.validate(input), isNotNull, reason: input);
    }
    expect(ServiceBudget.validate('1'), isNull);
    expect(ServiceBudget.validate('0,01'), isNull);
  });

  test('normaliza decimales sin redondear y siempre representa COP', () {
    expect(ServiceBudget.tryParse(' 00150000,25 ')!.amount, '150000.25');
    expect(ServiceBudget.tryParse('150000.25')!.label, '150.000,25 COP');
    expect(ServiceBudget.tryParse('0,0000000000000000001'), isNull);
    expect(ServiceBudget.currency, 'COP');
  });

  test('respeta el máximo técnico sin perder precisión', () {
    const amount = '9999999999.99';
    expect(ServiceBudget.tryParse(amount)!.amount, amount);
    expect(ServiceBudget.validate(amount), isNull);
  });

  test('rechaza texto, rangos y separadores de miles ambiguos', () {
    for (final input in [
      '10000000000',
      '1.001',
      '1.000',
      '9999999999.999',
      'abc',
      'NaN',
      'Infinity',
      '1e5',
      '+10',
      '100-200',
      '1.000.000',
      '150,000.50',
      '1 000',
      'COP 10',
      '12,',
      '.5',
    ]) {
      expect(ServiceBudget.tryParse(input), isNull, reason: input);
    }
  });
}
