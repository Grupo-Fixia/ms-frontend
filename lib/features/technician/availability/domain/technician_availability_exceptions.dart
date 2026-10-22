/// No se pudo consultar o guardar la disponibilidad o la zona de atención.
///
/// [fieldErrors] trae los errores por campo (validación local o `400` del
/// backend). [isSessionExpired] indica que hay que volver a iniciar sesión.
class TechnicianAvailabilityFailure implements Exception {
  const TechnicianAvailabilityFailure(
    this.message, {
    this.fieldErrors = const {},
    this.isSessionExpired = false,
  });

  final String message;
  final Map<String, String> fieldErrors;
  final bool isSessionExpired;

  @override
  String toString() => message;
}
