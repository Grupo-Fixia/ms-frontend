/// No se pudo consultar la empresa o sus técnicos asociados.
///
/// [isSessionExpired] indica que hay que volver a iniciar sesión.
class CompanyFailure implements Exception {
  const CompanyFailure(this.message, {this.isSessionExpired = false});

  final String message;
  final bool isSessionExpired;

  @override
  String toString() => message;
}
