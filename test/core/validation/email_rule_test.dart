import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/validation/email_rule.dart';

void main() {
  test('es obligatorio', () {
    expect(EmailRule.validate(null), 'Ingresa tu correo electrónico.');
    expect(EmailRule.validate('  '), 'Ingresa tu correo electrónico.');
  });

  test('acepta un correo válido y recorta espacios', () {
    expect(EmailRule.validate('ana@fixia.com'), isNull);
    expect(EmailRule.validate(' ana@fixia.com '), isNull);
  });

  test('rechaza formatos inválidos', () {
    for (final value in ['ana@', 'ana fixia.com', '@fixia.com', 'ana@fixia']) {
      expect(EmailRule.validate(value), isNotNull, reason: value);
    }
  });

  test('no supera 254 caracteres', () {
    expect(EmailRule.validate('${'a' * 244}@fixia.com'), isNull);
    expect(EmailRule.validate('${'a' * 245}@fixia.com'), isNotNull);
  });
}
