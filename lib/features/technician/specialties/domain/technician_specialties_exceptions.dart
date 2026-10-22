/// No se pudieron consultar o guardar las especialidades del técnico.
///
/// [fieldErrors] trae los errores por campo del backend (`400`).
/// [isSessionExpired] indica que hay que volver a iniciar sesión.
class TechnicianSpecialtiesFailure implements Exception {
  const TechnicianSpecialtiesFailure(
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
