/// Día de la semana de una franja de disponibilidad (`dayOfWeek` de
/// ms-users).
enum Weekday {
  monday('MONDAY', 'Lunes'),
  tuesday('TUESDAY', 'Martes'),
  wednesday('WEDNESDAY', 'Miércoles'),
  thursday('THURSDAY', 'Jueves'),
  friday('FRIDAY', 'Viernes'),
  saturday('SATURDAY', 'Sábado'),
  sunday('SUNDAY', 'Domingo');

  const Weekday(this.apiValue, this.label);

  /// Valor exacto que espera el backend.
  final String apiValue;

  /// Texto que ve el usuario.
  final String label;

  /// Devuelve `null` si el backend envía un día que el frontend no conoce.
  static Weekday? fromApi(String? value) {
    for (final day in values) {
      if (day.apiValue == value) return day;
    }
    return null;
  }
}
