/// No se pudo publicar o consultar una solicitud de servicio.
///
/// [fieldErrors] usa los nombres de campo del backend
/// (`approximateLocation.city`). [isSessionExpired] indica que hay que volver
/// a iniciar sesión.
class ServiceRequestFailure implements Exception {
  const ServiceRequestFailure(
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
