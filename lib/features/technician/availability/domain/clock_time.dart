/// Hora del día al minuto, en hora de Colombia (America/Bogota), como la
/// guarda ms-users. Se intercambia con el backend como `"HH:mm"`.
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  static final _pattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$');

  /// Acepta `"HH:mm"` (y `"HH:mm:ss"`, descartando los segundos); `null` si
  /// el texto no es una hora válida.
  static ClockTime? tryParse(String? value) {
    final match = value == null ? null : _pattern.firstMatch(value.trim());
    if (match == null) return null;
    return ClockTime(int.parse(match[1]!), int.parse(match[2]!));
  }

  int get minutesOfDay => hour * 60 + minute;

  /// `"HH:mm"`, el formato que espera el backend.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(ClockTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}
