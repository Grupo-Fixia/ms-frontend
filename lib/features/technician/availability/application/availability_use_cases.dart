import '../domain/availability_rules.dart';
import '../domain/coverage_zone.dart';
import '../domain/technician_availability_exceptions.dart';
import '../domain/weekly_availability.dart';
import 'ports/technician_availability_repository.dart';

/// Caso de uso: consultar la disponibilidad semanal del técnico (GC-295).
class GetWeeklyAvailability {
  const GetWeeklyAvailability(this._repository);

  final TechnicianAvailabilityRepository _repository;

  Future<WeeklyAvailability> call() => _repository.fetchAvailability();
}

/// Caso de uso: reemplazar la disponibilidad semanal (GC-295). Valida las
/// franjas antes de enviarlas.
class ReplaceWeeklyAvailability {
  const ReplaceWeeklyAvailability(this._repository);

  static const fieldName = 'slots';

  final TechnicianAvailabilityRepository _repository;

  Future<WeeklyAvailability> call(List<AvailabilitySlot> slots) async {
    final error = AvailabilityRules.slots(slots);
    if (error != null) {
      throw TechnicianAvailabilityFailure(
        error,
        fieldErrors: {fieldName: error},
      );
    }
    return _repository.replaceAvailability(List.unmodifiable(slots));
  }
}

/// Caso de uso: consultar la zona de atención (GC-295); `null` si no hay.
class GetCoverageZone {
  const GetCoverageZone(this._repository);

  final TechnicianAvailabilityRepository _repository;

  Future<CoverageZone?> call() => _repository.fetchCoverageZone();
}

/// Caso de uso: declarar o reemplazar la zona de atención (GC-295). Valida
/// los datos antes de enviarlos.
class UpdateCoverageZone {
  const UpdateCoverageZone(this._repository);

  static const invalidDataMessage = 'Revisa los datos de la zona de atención.';

  final TechnicianAvailabilityRepository _repository;

  Future<CoverageZone> call(CoverageZoneUpdate zone) async {
    final errors = AvailabilityRules.coverageZone(zone);
    if (errors.isNotEmpty) {
      throw TechnicianAvailabilityFailure(
        invalidDataMessage,
        fieldErrors: errors,
      );
    }
    return _repository.updateCoverageZone(
      CoverageZoneUpdate(
        city: zone.city.trim(),
        latitude: zone.latitude,
        longitude: zone.longitude,
        radiusKm: zone.radiusKm,
      ),
    );
  }
}

/// Caso de uso: retirar la zona de atención (GC-295).
class ClearCoverageZone {
  const ClearCoverageZone(this._repository);

  final TechnicianAvailabilityRepository _repository;

  Future<void> call() => _repository.clearCoverageZone();
}
