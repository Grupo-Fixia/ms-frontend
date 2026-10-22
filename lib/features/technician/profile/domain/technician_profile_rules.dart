import '../../../../core/constants/service_category.dart';

/// Reglas del perfil profesional. Replican las de `TechnicianProfileRequest`
/// en ms-users para que el técnico vea el error antes de guardar. Devuelven el
/// mensaje a mostrar o `null` si el valor es válido.
abstract final class TechnicianProfileRules {
  static const descriptionMaxLength = 1000;
  static const minYears = 0;
  static const maxYears = 80;

  static String? description(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Cuéntales a los clientes qué haces y en qué tienes experiencia.';
    }
    if (value.trim().length > descriptionMaxLength) {
      return 'La descripción no puede superar $descriptionMaxLength caracteres.';
    }
    return null;
  }

  static String? yearsOfExperience(int? value) {
    if (value == null) return 'Indica tus años de experiencia.';
    if (value < minYears || value > maxYears) {
      return 'Ingresa un número entre $minYears y $maxYears.';
    }
    return null;
  }

  /// Convierte lo que escribe el técnico; `null` si no es un número entero.
  static int? parseYears(String? text) => int.tryParse(text?.trim() ?? '');

  static String? categories(Set<ServiceCategory> value) =>
      value.isEmpty ? 'Elige al menos una categoría.' : null;
}
