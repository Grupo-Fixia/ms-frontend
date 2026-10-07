/// El formulario llegó incompleto: no se envía nada al backend (CA-12).
class InvalidClientRegistrationException implements Exception {
  const InvalidClientRegistrationException(this.missingFields);

  final List<String> missingFields;

  @override
  String toString() => 'InvalidClientRegistrationException($missingFields)';
}

/// El backend rechazó el registro o no se pudo contactar.
///
/// [fieldErrors] trae los errores por campo (`errors[]` del ProblemDetail de
/// ms-users) para mostrarlos debajo de cada input.
class ClientRegistrationFailure implements Exception {
  const ClientRegistrationFailure(
    this.message, {
    this.fieldErrors = const {},
  });

  final String message;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}
