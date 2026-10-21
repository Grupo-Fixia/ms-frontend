import '../application/ports/technician_availability_repository.dart';
import '../domain/availability_day.dart';
import '../domain/availability_hours.dart';
import '../domain/coverage_zone.dart';
import '../domain/technician_availability.dart';
import '../domain/technician_service_settings.dart';

class MockTechnicianAvailabilityRepository
    implements TechnicianAvailabilityRepository {
  TechnicianServiceSettings _settings = TechnicianServiceSettings(
    availability: TechnicianAvailability(days: {
      AvailabilityDay.monday:
          const AvailabilityHours(startMinutes: 480, endMinutes: 1020),
      AvailabilityDay.tuesday:
          const AvailabilityHours(startMinutes: 480, endMinutes: 1020),
      AvailabilityDay.wednesday:
          const AvailabilityHours(startMinutes: 480, endMinutes: 1020),
      AvailabilityDay.thursday:
          const AvailabilityHours(startMinutes: 480, endMinutes: 1020),
      AvailabilityDay.friday:
          const AvailabilityHours(startMinutes: 480, endMinutes: 1020),
      AvailabilityDay.saturday:
          const AvailabilityHours(startMinutes: 540, endMinutes: 840),
    }),
    coverageZone: const CoverageZone(city: 'Bogotá', radiusKm: 15),
  );

  @override
  Future<TechnicianServiceSettings> fetchSettings() async => _settings;

  @override
  Future<void> saveSettings(TechnicianServiceSettings settings) async {
    _settings = TechnicianServiceSettings(
      availability: TechnicianAvailability(days: settings.availability.days),
      coverageZone: CoverageZone(
          city: settings.coverageZone.city,
          radiusKm: settings.coverageZone.radiusKm),
    );
  }
}
