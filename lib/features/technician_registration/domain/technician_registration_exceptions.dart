/// El formulario llegó incompleto: no se realiza el envío.
class InvalidTechnicianRegistrationException implements Exception {
  const InvalidTechnicianRegistrationException(this.missingFields);

  final List<String> missingFields;

  @override
  String toString() => 'InvalidTechnicianRegistrationException($missingFields)';
}

/// El registro no pudo completarse.
class TechnicianRegistrationFailure implements Exception {
  const TechnicianRegistrationFailure(
    this.message, {
    this.fieldErrors = const {},
  });

  final String message;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}
