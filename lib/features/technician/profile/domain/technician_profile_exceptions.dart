/// No se pudo consultar o guardar el perfil profesional.
///
/// [fieldErrors] trae los errores por campo que devolvió el backend (`400`).
/// [isSessionExpired] indica que la sesión ya no es válida y hay que volver a
/// iniciar sesión.
class TechnicianProfileFailure implements Exception {
  const TechnicianProfileFailure(
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
