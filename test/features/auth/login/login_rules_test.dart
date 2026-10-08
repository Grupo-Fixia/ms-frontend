import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/domain/login_rules.dart';

void main() {
  group('LoginRules.email', () {
    test('exige el correo', () {
      expect(LoginRules.email(null), isNotNull);
      expect(LoginRules.email('   '), isNotNull);
    });

    test('rechaza correos sin forma de correo', () {
      expect(LoginRules.email('ana'), isNotNull);
      expect(LoginRules.email('ana@fixia'), isNotNull);
      expect(LoginRules.email('ana @fixia.com'), isNotNull);
    });

    test('acepta un correo válido, con espacios alrededor', () {
      expect(LoginRules.email('ana@fixia.com'), isNull);
      expect(LoginRules.email('  ana@fixia.com '), isNull);
    });
  });

  group('LoginRules.password', () {
    test('exige la contraseña', () {
      expect(LoginRules.password(null), isNotNull);
      expect(LoginRules.password(''), isNotNull);
    });

    test('no exige complejidad: solo se pide al registrarse', () {
      expect(LoginRules.password('a'), isNull);
    });

    test('rechaza más de 128 caracteres, el límite del backend', () {
      expect(LoginRules.password('a' * 128), isNull);
      expect(LoginRules.password('a' * 129), isNotNull);
    });
  });
}
