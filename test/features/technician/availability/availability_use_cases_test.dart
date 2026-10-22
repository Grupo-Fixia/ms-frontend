import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/technician/availability/application/availability_use_cases.dart';
import 'package:ms_frontend/features/technician/availability/application/ports/technician_availability_repository.dart';
import 'package:ms_frontend/features/technician/availability/domain/clock_time.dart';
import 'package:ms_frontend/features/technician/availability/domain/coverage_zone.dart';
import 'package:ms_frontend/features/technician/availability/domain/technician_availability_exceptions.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekday.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekly_availability.dart';

class _FakeRepository implements TechnicianAvailabilityRepository {
  List<AvailabilitySlot>? replaced;
  CoverageZoneUpdate? updated;
  int clearCalls = 0;

  @override
  Future<WeeklyAvailability> fetchAvailability() async =>
      const WeeklyAvailability(slots: []);

  @override
  Future<WeeklyAvailability> replaceAvailability(
    List<AvailabilitySlot> slots,
  ) async {
    replaced = slots;
    return WeeklyAvailability(slots: slots);
  }

  @override
  Future<CoverageZone?> fetchCoverageZone() async => null;

  @override
  Future<CoverageZone> updateCoverageZone(CoverageZoneUpdate zone) async {
    updated = zone;
    return CoverageZone(city: zone.city);
  }

  @override
  Future<void> clearCoverageZone() async => clearCalls++;
}

final _monday = AvailabilitySlot(
  day: Weekday.monday,
  start: ClockTime.tryParse('08:00')!,
  end: ClockTime.tryParse('12:00')!,
);

void main() {
  test('consulta disponibilidad y zona', () async {
    final repository = _FakeRepository();

    expect((await GetWeeklyAvailability(repository)()).slots, isEmpty);
    expect(await GetCoverageZone(repository)(), isNull);
  });

  test('reemplaza franjas válidas sin compartir la lista del llamador',
      () async {
    final repository = _FakeRepository();
    final slots = [_monday];

    await ReplaceWeeklyAvailability(repository)(slots);

    expect(repository.replaced, [_monday]);
    expect(() => repository.replaced!.add(_monday), throwsUnsupportedError);
  });

  test('no envía franjas inválidas', () async {
    final repository = _FakeRepository();
    final crossed = AvailabilitySlot(
      day: Weekday.monday,
      start: ClockTime.tryParse('10:00')!,
      end: ClockTime.tryParse('14:00')!,
    );

    await expectLater(
      ReplaceWeeklyAvailability(repository)([_monday, crossed]),
      throwsA(isA<TechnicianAvailabilityFailure>().having(
        (f) => f.fieldErrors.keys,
        'fieldErrors',
        [ReplaceWeeklyAvailability.fieldName],
      )),
    );
    expect(repository.replaced, isNull);
  });

  test('envía la zona con la ciudad sin espacios', () async {
    final repository = _FakeRepository();

    final saved = await UpdateCoverageZone(repository)(
      const CoverageZoneUpdate(
        city: '  Bogotá ',
        latitude: 4.65,
        longitude: -74.08,
        radiusKm: 10,
      ),
    );

    expect(saved.city, 'Bogotá');
    expect(repository.updated!.radiusKm, 10);
  });

  test('no envía una zona inválida', () async {
    final repository = _FakeRepository();

    await expectLater(
      UpdateCoverageZone(repository)(const CoverageZoneUpdate(city: '')),
      throwsA(isA<TechnicianAvailabilityFailure>()
          .having((f) => f.message, 'message',
              UpdateCoverageZone.invalidDataMessage)
          .having((f) => f.fieldErrors.keys, 'fieldErrors', ['city'])),
    );
    expect(repository.updated, isNull);
  });

  test('retira la zona', () async {
    final repository = _FakeRepository();

    await ClearCoverageZone(repository)();

    expect(repository.clearCalls, 1);
  });
}
