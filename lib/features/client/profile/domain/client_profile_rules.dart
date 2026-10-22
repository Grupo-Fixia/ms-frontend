abstract final class ClientProfileRules {
  static const nameMaxLength = 100;

  static String? name(String? value, {required String label}) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'El $label es obligatorio.';
    if (name.length > nameMaxLength) {
      return 'El $label no puede superar $nameMaxLength caracteres.';
    }
    return null;
  }

  static String? phone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'El teléfono es obligatorio.';
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)) {
      return 'Ingresa un teléfono válido de 7 a 15 dígitos.';
    }
    return null;
  }
}
