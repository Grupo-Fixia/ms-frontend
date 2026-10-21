import 'ports/technician_availability_repository.dart';
import '../domain/technician_service_settings.dart';

class SaveTechnicianServiceSettings {
  const SaveTechnicianServiceSettings(this._repository);
  final TechnicianAvailabilityRepository _repository;

  Future<void> call(TechnicianServiceSettings settings) {
    if (settings.availability.days.isEmpty ||
        settings.availability.days.values.any((hours) => !hours.isValid) ||
        !settings.coverageZone.isValid) {
      throw ArgumentError(
          'La disponibilidad o la zona de cobertura no son válidas.');
    }
    return _repository.saveSettings(settings);
  }
}
