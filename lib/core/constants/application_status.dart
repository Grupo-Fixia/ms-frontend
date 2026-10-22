/// Estado de una postulación (`ApplicationStatus` de ms-services). Lo usan
/// las postulaciones del técnico y los postulantes que ve el cliente.
enum ApplicationStatus {
  applied('APPLIED', 'Postulado'),
  selected('SELECTED', 'Seleccionado'),
  rejected('REJECTED', 'No seleccionado');

  const ApplicationStatus(this.apiValue, this.label);

  /// Valor exacto que usa el backend.
  final String apiValue;

  /// Texto que ve el usuario.
  final String label;

  /// Devuelve `null` si el backend envía un estado que el frontend no conoce.
  static ApplicationStatus? fromApi(String? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}
