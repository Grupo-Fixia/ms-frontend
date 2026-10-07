/// El backend rechazó la operación de autenticación o no se pudo contactar.
///
/// [fieldErrors] trae los errores por campo (`errors[]` del ProblemDetail de
/// ms-users) para mostrarlos debajo de cada input. [isUnauthorized] es `true`
/// cuando el backend respondió 401: la credencial o el token ya no sirven (a
/// diferencia de una falla de red, donde el token puede seguir siendo válido).
class AuthFailure implements Exception {
  const AuthFailure(
    this.message, {
    this.fieldErrors = const {},
    this.isUnauthorized = false,
  });

  final String message;
  final Map<String, String> fieldErrors;
  final bool isUnauthorized;

  @override
  String toString() => message;
}
