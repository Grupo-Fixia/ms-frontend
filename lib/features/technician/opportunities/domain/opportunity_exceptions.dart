/// No se pudieron consultar las oportunidades del técnico.
///
/// [isSessionExpired] indica que hay que volver a iniciar sesión.
class OpportunityFailure implements Exception {
  const OpportunityFailure(this.message, {this.isSessionExpired = false});

  final String message;
  final bool isSessionExpired;

  @override
  String toString() => message;
}
