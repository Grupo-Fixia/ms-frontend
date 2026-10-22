import '../application/ports/technician_availability_repository.dart';
import '../domain/clock_time.dart';
import '../domain/coverage_zone.dart';
import '../domain/weekday.dart';
import '../domain/weekly_availability.dart';

/// Implementación en memoria del puerto de disponibilidad para la demo sin
/// sesión. Con sesión real se usa `HttpTechnicianAvailabilityRepository`.
class DemoTechnicianAvailabilityRepository
    implements TechnicianAvailabilityRepository {
  DemoTechnicianAvailabilityRepository({
    List<AvailabilitySlot>? slots,
    CoverageZone? zone,
  })  : _slots = [...(slots ?? _defaultSlots)],
        _zone = zone ??
            const CoverageZone(
              city: 'Bogotá',
              latitude: 4.7110,
              longitude: -74.0721,
              radiusKm: 15,
            );

  static final _defaultSlots = [
    for (final day in Weekday.values.take(5))
      AvailabilitySlot(
        day: day,
        start: const ClockTime(8, 0),
        end: const ClockTime(17, 0),
      ),
  ];

  List<AvailabilitySlot> _slots;
  CoverageZone? _zone;

  @override
  Future<WeeklyAvailability> fetchAvailability() async =>
      WeeklyAvailability(slots: [..._slots]);

  @override
  Future<WeeklyAvailability> replaceAvailability(
    List<AvailabilitySlot> slots,
  ) async {
    _slots = [...slots];
    return WeeklyAvailability(slots: [..._slots], updatedAt: DateTime.now());
  }

  @override
  Future<CoverageZone?> fetchCoverageZone() async => _zone;

  @override
  Future<CoverageZone> updateCoverageZone(CoverageZoneUpdate zone) async {
    return _zone = CoverageZone(
      city: zone.city,
      latitude: zone.latitude,
      longitude: zone.longitude,
      radiusKm: zone.radiusKm,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearCoverageZone() async => _zone = null;
}
