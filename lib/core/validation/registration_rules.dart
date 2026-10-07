import 'email_rule.dart';
import '../models/document_type.dart';

/// Reglas compartidas de validación de registro.
///
/// Replican las de `ClientRegistrationRequest` en ms-users para que el
/// usuario vea el error antes de enviar. Devuelven el mensaje a mostrar o
/// `null` si el valor es válido.
abstract final class ClientRegistrationRules {
  static final _digitsPattern = RegExp(r'^[0-9]+$');
  static final _alphanumericPattern = RegExp(r'^[A-Za-z0-9]+$');
  static final _phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
  static final _lettersAndDigits = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).*$');

  static const nameMaxLength = 100;
  static const documentMaxLength = 30;
  static const emailMaxLength = EmailRule.maxLength;
  static const passwordMinLength = 8;
  static const passwordMaxLength = 20;

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static String? firstName(String? value) {
    if (_isBlank(value)) return 'Ingresa tu nombre.';
    if (value!.trim().length > nameMaxLength) {
      return 'El nombre no puede superar $nameMaxLength caracteres.';
    }
    return null;
  }

  static String? lastName(String? value) {
    if (_isBlank(value)) return 'Ingresa tu apellido.';
    if (value!.trim().length > nameMaxLength) {
      return 'El apellido no puede superar $nameMaxLength caracteres.';
    }
    return null;
  }

  /// La cédula de ciudadanía y la de extranjería son solo números; el
  /// pasaporte admite letras y números (como lo acepta ms-users).
  static bool documentAllowsLetters(DocumentType? type) =>
      type == DocumentType.passport;

  static String? documentNumber(String? value, DocumentType? type) {
    if (_isBlank(value)) return 'Ingresa tu número de documento.';
    final trimmed = value!.trim();
    if (trimmed.length > documentMaxLength) {
      return 'El documento no puede superar $documentMaxLength caracteres.';
    }
    if (documentAllowsLetters(type)) {
      if (!_alphanumericPattern.hasMatch(trimmed)) {
        return 'Usa solo letras y números, sin espacios ni símbolos.';
      }
    } else if (!_digitsPattern.hasMatch(trimmed)) {
      return 'Usa solo números, sin puntos ni espacios.';
    }
    return null;
  }

  static String? email(String? value) => EmailRule.validate(value);

  static String? phone(String? value) {
    if (_isBlank(value)) return 'Ingresa tu teléfono.';
    if (!_phonePattern.hasMatch(value!.trim())) {
      return 'Ingresa solo números (7 a 15 dígitos).';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Crea una contraseña.';
    if (value.length < passwordMinLength ||
        value.length > passwordMaxLength ||
        !_lettersAndDigits.hasMatch(value)) {
      return 'Usa entre $passwordMinLength y $passwordMaxLength caracteres, '
          'con letras y números.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña.';
    return value == password ? null : 'Las contraseñas no coinciden.';
  }
}
