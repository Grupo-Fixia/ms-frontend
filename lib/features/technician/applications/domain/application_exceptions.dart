/// Motivo por el que el técnico no puede postularse (lo decide ms-users).
enum IneligibilityReason {
  verification(
    'VERIFICATION',
    'Tu perfil aún no está verificado.',
  ),
  category(
    'CATEGORY',
    'No ofreces la especialidad que pide la solicitud.',
  ),
  zone(
    'ZONE',
    'La solicitud está fuera de tu zona de atención.',
  ),
  availability(
    'AVAILABILITY',
    'No tienes disponibilidad para el momento de la solicitud.',
  ),
  technicianNotFound(
    'TECHNICIAN_NOT_FOUND',
    'No encontramos tu perfil de técnico.',
  );

  const IneligibilityReason(this.apiValue, this.message);

  /// Valor exacto que usa el backend.
  final String apiValue;

  /// Explicación para el técnico.
  final String message;

  /// Devuelve `null` si el backend envía un motivo que el frontend no conoce.
  static IneligibilityReason? fromApi(String? value) {
    for (final reason in values) {
      if (reason.apiValue == value) return reason;
    }
    return null;
  }
}

/// No se pudo registrar o consultar una postulación.
///
/// - [reasons]: por qué el técnico no es elegible (`422`).
/// - [existingApplicationId]: la postulación que ya existe si el técnico ya
///   se había postulado (`409`).
/// - [isSessionExpired]: hay que volver a iniciar sesión.
class ApplicationFailure implements Exception {
  const ApplicationFailure(
    this.message, {
    this.fieldErrors = const {},
    this.reasons = const [],
    this.existingApplicationId,
    this.isSessionExpired = false,
  });

  final String message;
  final Map<String, String> fieldErrors;
  final List<IneligibilityReason> reasons;
  final String? existingApplicationId;
  final bool isSessionExpired;

  bool get isNotEligible => reasons.isNotEmpty;
  bool get isDuplicate => existingApplicationId != null;

  @override
  String toString() => message;
}
