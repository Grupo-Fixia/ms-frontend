import '../../domain/coverage_zone.dart';
import '../../domain/weekly_availability.dart';

/// Puerto de salida: disponibilidad y zona de atención del técnico
/// autenticado (GC-330).
///
/// Todos los métodos lanzan `TechnicianAvailabilityFailure` si el backend
/// rechaza la solicitud o no se puede contactar.
abstract interface class TechnicianAvailabilityRepository {
  Future<WeeklyAvailability> fetchAvailability();

  /// Reemplaza todas las franjas; una lista vacía las retira.
  Future<WeeklyAvailability> replaceAvailability(List<AvailabilitySlot> slots);

  /// `null` si el técnico aún no ha declarado zona.
  Future<CoverageZone?> fetchCoverageZone();

  Future<CoverageZone> updateCoverageZone(CoverageZoneUpdate zone);

  Future<void> clearCoverageZone();
}
