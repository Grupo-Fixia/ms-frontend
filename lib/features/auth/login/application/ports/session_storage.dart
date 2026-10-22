/// Puerto de salida: dónde se guarda el refresh token para recuperar la sesión
/// (GC-394). El access token nunca se guarda.
///
/// La sesión es una sola en todo el navegador: una pestaña nueva entra con la
/// sesión ya iniciada. "Mantener sesión iniciada" decide si sobrevive a cerrar
/// el navegador. Cada pestaña guarda además una copia para recargar (F5).
abstract interface class SessionStorage {
  /// El token de la sesión del navegador o, si no hay, la copia de la
  /// pestaña. Es el más nuevo: lo comparten todas las pestañas.
  Future<String?> readRefreshToken();

  /// Guarda el token de una sesión nueva, que pasa a ser la del navegador.
  /// Con [persist] sobrevive a cerrar el navegador.
  Future<void> saveRefreshToken(String refreshToken, {bool persist = false});

  /// Reemplaza el token tras rotarlo (es de un solo uso), si esta pestaña
  /// sigue siendo de la sesión del navegador.
  Future<void> replaceRefreshToken(String refreshToken);

  /// Cierra la sesión: borra la copia de la pestaña y, si es de la sesión
  /// del navegador, también esa.
  Future<void> clear();

  /// Otra pestaña cambió la sesión del navegador: si la copia de esta
  /// pestaña era de la sesión anterior, se descarta sin tocar la nueva.
  Future<void> discardStaleTabCopy();
}
