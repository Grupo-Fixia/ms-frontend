import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/registration/domain/registration_rules.dart';
import 'package:ms_frontend/features/auth/registration/domain/document_type.dart';

void main() {
  group('nombres y apellidos', () {
    test('son obligatorios', () {
      expect(RegistrationRules.firstName('  '), isNotNull);
      expect(RegistrationRules.lastName(null), isNotNull);
    });

    test('aceptan hasta 100 caracteres', () {
      expect(RegistrationRules.firstName('a' * 100), isNull);
      expect(RegistrationRules.firstName('a' * 101), isNotNull);
      expect(RegistrationRules.lastName('b' * 100), isNull);
      expect(RegistrationRules.lastName('b' * 101), isNotNull);
    });
  });

  group('documento', () {
    test('es obligatorio', () {
      expect(RegistrationRules.documentNumber('', DocumentType.cc),
          isNotNull);
    });

    test('cédula de ciudadanía y de extranjería: solo números', () {
      for (final type in [DocumentType.cc, DocumentType.ce]) {
        expect(RegistrationRules.documentNumber('1020304050', type),
            isNull);
        expect(RegistrationRules.documentNumber('AB123', type),
            isNotNull);
        expect(RegistrationRules.documentNumber('1.020.304', type),
            isNotNull);
      }
      expect(RegistrationRules.documentAllowsLetters(DocumentType.cc),
          isFalse);
    });

    test('pasaporte: letras y números, sin símbolos', () {
      const type = DocumentType.passport;
      expect(RegistrationRules.documentAllowsLetters(type), isTrue);
      expect(RegistrationRules.documentNumber('AB123456', type), isNull);
      expect(RegistrationRules.documentNumber('AB-123', type),
          isNotNull);
    });

    test('sin tipo elegido se exigen solo números', () {
      expect(RegistrationRules.documentNumber('AB1', null), isNotNull);
      expect(RegistrationRules.documentNumber('123', null), isNull);
    });

    test('acepta hasta 30 caracteres y recorta espacios externos', () {
      expect(RegistrationRules.documentNumber('1' * 30, DocumentType.cc),
          isNull);
      expect(RegistrationRules.documentNumber('1' * 31, DocumentType.cc),
          isNotNull);
      expect(RegistrationRules.documentNumber(' 123 ', DocumentType.cc),
          isNull);
    });
  });

  group('correo', () {
    test('es obligatorio y debe tener formato válido', () {
      expect(RegistrationRules.email(''), isNotNull);
      expect(RegistrationRules.email('ana@fixia.com'), isNull);
      expect(RegistrationRules.email('ana@'), isNotNull);
      expect(RegistrationRules.email('ana fixia.com'), isNotNull);
    });

    test('no supera 254 caracteres', () {
      final local = 'a' * 245;
      expect(RegistrationRules.email('$local@fixia.com'), isNotNull);
    });
  });

  group('teléfono', () {
    test('admite 7 a 15 dígitos con + opcional', () {
      expect(RegistrationRules.phone(''), isNotNull);
      expect(RegistrationRules.phone('3001234567'), isNull);
      expect(RegistrationRules.phone('+573001234567'), isNull);
      expect(RegistrationRules.phone('123456'), isNotNull);
      expect(RegistrationRules.phone('1234567890123456'), isNotNull);
      expect(RegistrationRules.phone('300-123-4567'), isNotNull);
    });
  });

  group('contraseña', () {
    test('exige 8 a 20 caracteres con letras y números', () {
      expect(RegistrationRules.password(''), isNotNull);
      expect(RegistrationRules.password('Segura123'), isNull);
      expect(RegistrationRules.password('Abc1234'), isNotNull);
      expect(RegistrationRules.password('solotexto'), isNotNull);
      expect(RegistrationRules.password('12345678'), isNotNull);
      expect(RegistrationRules.password('a1${'x' * 18}'), isNull);
      expect(RegistrationRules.password('a1${'x' * 19}'), isNotNull);
      expect(RegistrationRules.passwordMaxLength, 20);
    });

    test('la confirmación debe coincidir', () {
      expect(RegistrationRules.confirmPassword('', 'Segura123'),
          isNotNull);
      expect(RegistrationRules.confirmPassword('Otra1234', 'Segura123'),
          isNotNull);
      expect(RegistrationRules.confirmPassword('Segura123', 'Segura123'),
          isNull);
    });
  });
}
