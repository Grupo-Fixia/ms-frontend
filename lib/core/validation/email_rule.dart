/// Validación del correo electrónico, compartida por registro e inicio de
/// sesión (mismos límites que ms-users: formato válido y máximo 254
/// caracteres).
abstract final class EmailRule {
  static const maxLength = 254;

  static final _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Devuelve el mensaje a mostrar o `null` si el correo es válido.
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }
    final trimmed = value.trim();
    if (trimmed.length > maxLength || !_pattern.hasMatch(trimmed)) {
      return 'Ingresa un correo válido, por ejemplo nombre@correo.com.';
    }
    return null;
  }
}
