/// Puerto de salida: dónde se guarda el refresh token para recuperar la sesión
/// al recargar la página (GC-394). El access token nunca se guarda.
///
/// Hay dos alcances:
/// - **Pestaña** (`sessionStorage`): siempre. La sesión sobrevive a un F5 y se
///   borra sola al cerrar la pestaña.
/// - **Persistente** (`localStorage`): solo con "Mantener sesión iniciada". La
///   sesión sobrevive a cerrar el navegador.
abstract interface class SessionStorage {
  /// Token de la pestaña o, si no hay, el persistente.
  Future<String?> readRefreshToken();

  /// Guarda el token de una sesión nueva. Con [persist] también lo guarda en
  /// el alcance persistente; sin él borra cualquier token persistente viejo.
  Future<void> saveRefreshToken(String refreshToken, {bool persist = false});

  /// Reemplaza el token tras rotarlo (es de un solo uso) sin cambiar el
  /// alcance que eligió el usuario al iniciar sesión.
  Future<void> replaceRefreshToken(String refreshToken);

  /// Borra el token de ambos alcances.
  Future<void> clear();
}
