/// No se pudo consultar el historial o sus evaluaciones, o no se pudo
/// registrar una evaluación.
///
/// [isSessionExpired] indica que hay que volver a iniciar sesión.
/// [alreadyEvaluated]: ya existe una evaluación de quien califica para ese
/// servicio (GC-445, 409 de ms-users).
/// [notAllowed]: ms-users no admite evaluar ese servicio (servicio sin
/// cerrar, de empresa, fuera de plazo…); reintentar no cambia el resultado.
class ServiceHistoryFailure implements Exception {
  const ServiceHistoryFailure(
    this.message, {
    this.isSessionExpired = false,
    this.alreadyEvaluated = false,
    this.notAllowed = false,
  });

  final String message;
  final bool isSessionExpired;
  final bool alreadyEvaluated;
  final bool notAllowed;

  @override
  String toString() => message;
}
