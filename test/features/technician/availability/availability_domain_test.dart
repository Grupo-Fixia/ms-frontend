import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/technician/availability/domain/availability_rules.dart';
import 'package:ms_frontend/features/technician/availability/domain/clock_time.dart';
import 'package:ms_frontend/features/technician/availability/domain/coverage_zone.dart';
import 'package:ms_frontend/features/technician/availability/domain/technician_availability_exceptions.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekday.dart';
import 'package:ms_frontend/features/technician/availability/domain/weekly_availability.dart';

AvailabilitySlot _slot(Weekday day, String start, String end) =>
    AvailabilitySlot(
      day: day,
      start: ClockTime.tryParse(start)!,
      end: ClockTime.tryParse(end)!,
    );

void main() {
  group('Weekday', () {
    test('convierte los valores del backend', () {
      expect(Weekday.fromApi('MONDAY'), Weekday.monday);
      expect(Weekday.fromApi('SUNDAY')!.label, 'Domingo');
      expect(Weekday.fromApi('OTRO'), isNull);
      expect(Weekday.fromApi(null), isNull);
    });
  });

  group('ClockTime', () {
    test('lee "HH:mm" y "HH:mm:ss" y se escribe como "HH:mm"', () {
      expect(ClockTime.tryParse('08:05')!.format(), '08:05');
      expect(ClockTime.tryParse(' 23:59:30 '), const ClockTime(23, 59));
      expect(const ClockTime(7, 0).toString(), '07:00');
    });

    test('rechaza horas inválidas', () {
      for (final value in [null, '', '24:00', '8:00', '12:60', 'abc']) {
        expect(ClockTime.tryParse(value), isNull, reason: '$value');
      }
    });

    test('compara por minuto del día', () {
      const early = ClockTime(8, 0);
      const late = ClockTime(12, 30);

      expect(early.compareTo(late), lessThan(0));
      expect(late.minutesOfDay, 750);
      expect(early, const ClockTime(8, 0));
      expect(early.hashCode, const ClockTime(8, 0).hashCode);
    });
  });

  group('AvailabilitySlot', () {
    test('se cruzan si comparten minutos el mismo día', () {
      final morning = _slot(Weekday.monday, '08:00', '12:00');

      expect(morning.overlaps(_slot(Weekday.monday, '11:00', '13:00')), isTrue);
      expect(
          morning.overlaps(_slot(Weekday.monday, '12:00', '14:00')), isFalse);
      expect(
          morning.overlaps(_slot(Weekday.tuesday, '09:00', '10:00')), isFalse);
    });

    test('igualdad y texto', () {
      final slot = _slot(Weekday.friday, '08:00', '12:00');

      expect(slot, _slot(Weekday.friday, '08:00', '12:00'));
      expect(slot.hashCode, _slot(Weekday.friday, '08:00', '12:00').hashCode);
      expect(slot.toString(), 'Viernes 08:00-12:00');
    });
  });

  group('AvailabilityRules.slots', () {
    test('franjas válidas, seguidas o vacías', () {
      expect(AvailabilityRules.slots([]), isNull);
      expect(
        AvailabilityRules.slots([
          _slot(Weekday.monday, '08:00', '12:00'),
          _slot(Weekday.monday, '12:00', '14:00'),
          _slot(Weekday.tuesday, '08:00', '12:00'),
        ]),
        isNull,
      );
    });

    test('la repetida cuenta una vez (como en el backend)', () {
      expect(
        AvailabilityRules.slots([
          _slot(Weekday.monday, '08:00', '12:00'),
          _slot(Weekday.monday, '08:00', '12:00'),
        ]),
        isNull,
      );
    });

    test('el inicio debe ser anterior al fin', () {
      expect(
        AvailabilityRules.slots([_slot(Weekday.monday, '12:00', '12:00')]),
        contains('anterior'),
      );
    });

    test('no pueden cruzarse', () {
      expect(
        AvailabilityRules.slots([
          _slot(Weekday.monday, '08:00', '12:00'),
          _slot(Weekday.monday, '10:00', '14:00'),
        ]),
        contains('se cruzan'),
      );
    });
  });

  group('AvailabilityRules.coverageZone', () {
    test('solo ciudad es válido', () {
      expect(
        AvailabilityRules.coverageZone(
            const CoverageZoneUpdate(city: 'Bogotá')),
        isEmpty,
      );
    });

    test('con círculo completo es válido', () {
      expect(
        AvailabilityRules.coverageZone(const CoverageZoneUpdate(
          city: 'Bogotá',
          latitude: 4.65,
          longitude: -74.08,
          radiusKm: 15,
        )),
        isEmpty,
      );
    });

    test('la ciudad es obligatoria y tiene máximo 100 caracteres', () {
      expect(
        AvailabilityRules.coverageZone(const CoverageZoneUpdate(city: '  ')),
        contains('city'),
      );
      expect(
        AvailabilityRules.coverageZone(
            CoverageZoneUpdate(city: 'a' * 101))['city'],
        contains('100'),
      );
    });

    test('el círculo va completo o no va', () {
      expect(
        AvailabilityRules.coverageZone(
          const CoverageZoneUpdate(city: 'Bogotá', latitude: 4.65),
        ),
        contains('radiusKm'),
      );
    });

    test('valida rangos de latitud, longitud y radio', () {
      final errors = AvailabilityRules.coverageZone(const CoverageZoneUpdate(
        city: 'Bogotá',
        latitude: 91,
        longitude: -181,
        radiusKm: 101,
      ));

      expect(errors.keys, containsAll(['latitude', 'longitude', 'radiusKm']));
      expect(
        AvailabilityRules.coverageZone(const CoverageZoneUpdate(
          city: 'Bogotá',
          latitude: double.nan,
          longitude: 0,
          radiusKm: 0,
        )).keys,
        containsAll(['latitude', 'radiusKm']),
      );
    });
  });

  test('zona: indica si tiene círculo', () {
    expect(const CoverageZone(city: 'Bogotá').hasCircle, isFalse);
    expect(
      const CoverageZone(
        city: 'Bogotá',
        latitude: 4.65,
        longitude: -74.08,
        radiusKm: 5,
      ).hasCircle,
      isTrue,
    );
  });

  test('la falla se muestra con su mensaje', () {
    expect(
        const TechnicianAvailabilityFailure('Mensaje').toString(), 'Mensaje');
  });
}
