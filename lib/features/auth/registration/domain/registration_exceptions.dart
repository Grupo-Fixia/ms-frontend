/// El formulario llegó incompleto: no se envía nada al backend (CA-12).
class InvalidRegistrationException implements Exception {
  const InvalidRegistrationException(this.missingFields);

  final List<String> missingFields;

  @override
  String toString() => 'InvalidRegistrationException($missingFields)';
}

/// El backend rechazó el registro o no se pudo contactar.
///
/// [fieldErrors] trae los errores por campo (`errors[]` del ProblemDetail de
/// ms-users) para mostrarlos debajo de cada input. [isAccountConflict] es
/// `true` cuando ya existe una cuenta con ese correo o documento (409).
class RegistrationFailure implements Exception {
  const RegistrationFailure(
    this.message, {
    this.fieldErrors = const {},
    this.isAccountConflict = false,
  });

  final String message;
  final Map<String, String> fieldErrors;
  final bool isAccountConflict;

  @override
  String toString() => message;
}
