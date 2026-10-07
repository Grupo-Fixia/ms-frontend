import '../../../../core/validation/email_rule.dart';

/// Reglas de validación del formulario de inicio de sesión.
///
/// Solo comprueban que el dato exista y tenga forma de correo: la fortaleza
/// de la contraseña se exige al registrarse, no al entrar. Devuelven el
/// mensaje a mostrar o `null` si el valor es válido.
abstract final class LoginRules {
  static const passwordMaxLength = 128;

  static String? email(String? value) => EmailRule.validate(value);

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña.';
    if (value.length > passwordMaxLength) {
      return 'La contraseña no puede superar $passwordMaxLength caracteres.';
    }
    return null;
  }
}
