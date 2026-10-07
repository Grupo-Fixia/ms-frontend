/// El backend rechazó la operación de autenticación o no se pudo contactar.
///
/// [fieldErrors] trae los errores por campo (`errors[]` del ProblemDetail de
/// ms-users) para mostrarlos debajo de cada input.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}
