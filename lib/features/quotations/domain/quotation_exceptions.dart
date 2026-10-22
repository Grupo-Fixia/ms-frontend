/// No se pudo enviar o consultar una cotización.
///
/// [fieldErrors] usa los nombres de campo del backend. [isSessionExpired]
/// indica que hay que volver a iniciar sesión.
class QuotationFailure implements Exception {
  const QuotationFailure(
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
