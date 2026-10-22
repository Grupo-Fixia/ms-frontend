import 'coverage_zone.dart';
import 'weekly_availability.dart';

/// Reglas de la disponibilidad y la zona de atención.
///
/// Replican las de ms-users (`AvailabilitySlot`, `Technician` y
/// `CoverageZoneRequest`) para que el técnico vea el error antes de enviar.
abstract final class AvailabilityRules {
  static const cityMaxLength = 100;
  static const minRadiusKm = 1;
  static const maxRadiusKm = 100;

  /// Mensaje del primer problema de las franjas, o `null` si son válidas.
  static String? slots(List<AvailabilitySlot> slots) {
    for (final slot in slots) {
      if (slot.start.compareTo(slot.end) >= 0) {
        return 'En $slot la hora de inicio debe ser anterior a la de fin.';
      }
    }
    final distinct = slots.toSet().toList();
    for (var i = 0; i < distinct.length; i++) {
      for (var j = i + 1; j < distinct.length; j++) {
        if (distinct[i].overlaps(distinct[j])) {
          return 'Las franjas ${distinct[i]} y ${distinct[j]} se cruzan.';
        }
      }
    }
    return null;
  }

  /// Errores por campo (`city`, `latitude`, `longitude`, `radiusKm`); vacío
  /// si la zona es válida.
  static Map<String, String> coverageZone(CoverageZoneUpdate zone) {
    final errors = <String, String>{};
    final city = zone.city.trim();
    if (city.isEmpty) {
      errors['city'] = 'Ingresa la ciudad donde atiendes.';
    } else if (city.length > cityMaxLength) {
      errors['city'] = 'La ciudad no puede superar $cityMaxLength caracteres.';
    }

    final circle = [zone.latitude, zone.longitude, zone.radiusKm];
    if (circle.every((value) => value == null)) return errors;
    if (circle.any((value) => value == null)) {
      errors['radiusKm'] =
          'Para precisar la zona indica ubicación y radio, o deja los tres vacíos.';
      return errors;
    }
    final latitude = zone.latitude!;
    final longitude = zone.longitude!;
    final radius = zone.radiusKm!;
    if (latitude.isNaN || latitude < -90 || latitude > 90) {
      errors['latitude'] = 'La latitud debe estar entre -90 y 90.';
    }
    if (longitude.isNaN || longitude < -180 || longitude > 180) {
      errors['longitude'] = 'La longitud debe estar entre -180 y 180.';
    }
    if (radius < minRadiusKm || radius > maxRadiusKm) {
      errors['radiusKm'] =
          'El radio debe estar entre $minRadiusKm y $maxRadiusKm km.';
    }
    return errors;
  }
}
