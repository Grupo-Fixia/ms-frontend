/// No se pudo consultar o guardar el perfil del cliente.
///
/// [fieldErrors] trae los errores por campo (`firstName`, `lastName`,
/// `phone`). [isSessionExpired] indica que hay que volver a iniciar sesión.
class ClientProfileFailure implements Exception {
  const ClientProfileFailure(
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
