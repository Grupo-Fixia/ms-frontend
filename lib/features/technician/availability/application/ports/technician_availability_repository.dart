import '../../domain/technician_service_settings.dart';

abstract interface class TechnicianAvailabilityRepository {
  Future<TechnicianServiceSettings> fetchSettings();
  Future<void> saveSettings(TechnicianServiceSettings settings);
}
