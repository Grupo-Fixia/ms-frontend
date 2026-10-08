/// Estado de verificación del técnico (`VerificationStatus` de ms-users). Lo
/// define el equipo de Fixia; al registrarse siempre es pendiente.
enum VerificationStatus {
  pending('PENDING', 'Pendiente de verificación'),
  valid('VALID', 'Verificado'),
  rejected('REJECTED', 'Verificación rechazada'),
  expired('EXPIRED', 'Verificación vencida');

  const VerificationStatus(this.apiValue, this.label);

  /// Valor exacto que envía el backend.
  final String apiValue;

  /// Texto que ve el técnico.
  final String label;

  /// Devuelve `null` si el backend envía un estado que el frontend no conoce.
  static VerificationStatus? fromApi(String? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}
