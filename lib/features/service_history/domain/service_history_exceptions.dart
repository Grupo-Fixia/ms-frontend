/// No se pudo consultar el historial o sus evaluaciones.
///
/// [isSessionExpired] indica que hay que volver a iniciar sesión.
class ServiceHistoryFailure implements Exception {
  const ServiceHistoryFailure(this.message, {this.isSessionExpired = false});

  final String message;
  final bool isSessionExpired;

  @override
  String toString() => message;
}
