import 'clock_time.dart';
import 'weekday.dart';

/// Franja semanal en la que el técnico atiende (RF-011).
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.day,
    required this.start,
    required this.end,
  });

  final Weekday day;
  final ClockTime start;
  final ClockTime end;

  /// Dos franjas del mismo día se cruzan si comparten algún minuto; dos
  /// seguidas (08:00-12:00 y 12:00-14:00) no se cruzan.
  bool overlaps(AvailabilitySlot other) =>
      day == other.day &&
      start.compareTo(other.end) < 0 &&
      other.start.compareTo(end) < 0;

  @override
  bool operator ==(Object other) =>
      other is AvailabilitySlot &&
      other.day == day &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(day, start, end);

  @override
  String toString() => '${day.label} ${start.format()}-${end.format()}';
}

/// Disponibilidad semanal del técnico. Las horas son de Colombia.
class WeeklyAvailability {
  const WeeklyAvailability({
    required this.slots,
    this.timeZone = 'America/Bogota',
    this.updatedAt,
  });

  /// Ordenadas por día y hora de inicio. Vacía si aún no hay franjas.
  final List<AvailabilitySlot> slots;
  final String timeZone;
  final DateTime? updatedAt;
}
