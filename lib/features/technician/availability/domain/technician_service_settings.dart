import 'coverage_zone.dart';
import 'technician_availability.dart';

class TechnicianServiceSettings {
  const TechnicianServiceSettings(
      {required this.availability, required this.coverageZone});

  final TechnicianAvailability availability;
  final CoverageZone coverageZone;
}
