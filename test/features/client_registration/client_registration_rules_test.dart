import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/client_registration/domain/client_registration_rules.dart';

void main() {
  group('nombres y apellidos', () {
    test('son obligatorios', () {
      expect(ClientRegistrationRules.firstName('  '), isNotNull);
      expect(ClientRegistrationRules.lastName(null), isNotNull);
    });

    test('aceptan hasta 100 caracteres', () {
      expect(ClientRegistrationRules.firstName('a' * 100), isNull);
      expect(ClientRegistrationRules.firstName('a' * 101), isNotNull);
      expect(ClientRegistrationRules.lastName('b' * 100), isNull);
      expect(ClientRegistrationRules.lastName('b' * 101), isNotNull);
    });
  });

  group('documento', () {
    test('es obligatorio y solo admite letras y números', () {
      expect(ClientRegistrationRules.documentNumber(''), isNotNull);
      expect(ClientRegistrationRules.documentNumber('AB123'), isNull);
      expect(ClientRegistrationRules.documentNumber('1.020.304'), isNotNull);
      expect(ClientRegistrationRules.documentNumber('AB 12'), isNotNull);
    });

    test('acepta hasta 30 caracteres y recorta espacios externos', () {
      expect(ClientRegistrationRules.documentNumber('1' * 30), isNull);
      expect(ClientRegistrationRules.documentNumber('1' * 31), isNotNull);
      expect(ClientRegistrationRules.documentNumber(' AB123 '), isNull);
    });
  });

  group('correo', () {
    test('es obligatorio y debe tener formato válido', () {
      expect(ClientRegistrationRules.email(''), isNotNull);
      expect(ClientRegistrationRules.email('ana@fixia.com'), isNull);
      expect(ClientRegistrationRules.email('ana@'), isNotNull);
      expect(ClientRegistrationRules.email('ana fixia.com'), isNotNull);
    });

    test('no supera 254 caracteres', () {
      final local = 'a' * 245;
      expect(ClientRegistrationRules.email('$local@fixia.com'), isNotNull);
    });
  });

  group('teléfono', () {
    test('admite 7 a 15 dígitos con + opcional', () {
      expect(ClientRegistrationRules.phone(''), isNotNull);
      expect(ClientRegistrationRules.phone('3001234567'), isNull);
      expect(ClientRegistrationRules.phone('+573001234567'), isNull);
      expect(ClientRegistrationRules.phone('123456'), isNotNull);
      expect(ClientRegistrationRules.phone('1234567890123456'), isNotNull);
      expect(ClientRegistrationRules.phone('300-123-4567'), isNotNull);
    });
  });

  group('contraseña', () {
    test('exige 8 a 72 caracteres con letras y números', () {
      expect(ClientRegistrationRules.password(''), isNotNull);
      expect(ClientRegistrationRules.password('Segura123'), isNull);
      expect(ClientRegistrationRules.password('Abc1234'), isNotNull);
      expect(ClientRegistrationRules.password('solotexto'), isNotNull);
      expect(ClientRegistrationRules.password('12345678'), isNotNull);
      expect(ClientRegistrationRules.password('a1${'x' * 70}'), isNull);
      expect(ClientRegistrationRules.password('a1${'x' * 71}'), isNotNull);
    });

    test('la confirmación debe coincidir', () {
      expect(ClientRegistrationRules.confirmPassword('', 'Segura123'),
          isNotNull);
      expect(ClientRegistrationRules.confirmPassword('Otra1234', 'Segura123'),
          isNotNull);
      expect(ClientRegistrationRules.confirmPassword('Segura123', 'Segura123'),
          isNull);
    });
  });
}
