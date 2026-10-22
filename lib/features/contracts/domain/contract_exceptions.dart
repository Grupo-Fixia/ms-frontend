/// No se pudo consultar una contratación.
///
/// [isNotFound] indica que la solicitud aún no está contratada (o no es del
/// usuario). [isSessionExpired] indica que hay que volver a iniciar sesión.
class ContractFailure implements Exception {
  const ContractFailure(
    this.message, {
    this.isNotFound = false,
    this.isSessionExpired = false,
  });

  final String message;
  final bool isNotFound;
  final bool isSessionExpired;

  @override
  String toString() => message;
}
