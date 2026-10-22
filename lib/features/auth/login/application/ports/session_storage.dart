/// Puerto de salida: dónde se guarda el refresh token para recuperar la sesión
/// al recargar la página (GC-394). El access token nunca se guarda.
///
/// Hay dos alcances:
/// - **Pestaña** (`sessionStorage`): siempre. La sesión sobrevive a un F5 y se
///   borra sola al cerrar la pestaña.
/// - **Persistente** (`localStorage`): solo con "Mantener sesión iniciada". La
///   sesión sobrevive a cerrar el navegador.
abstract interface class SessionStorage {
  /// El token de esta pestaña. Si la pestaña es de la sesión persistente (o
  /// es nueva y no tiene sesión), el persistente, que comparten sus pestañas y
  /// siempre es el más nuevo. Nunca el de otra cuenta abierta en otra pestaña.
  Future<String?> readRefreshToken();

  /// Guarda el token de una sesión nueva. Con [persist] también lo guarda en
  /// el alcance persistente; sin él olvida la sesión persistente solo si era
  /// de esta pestaña.
  Future<void> saveRefreshToken(String refreshToken, {bool persist = false});

  /// Reemplaza el token tras rotarlo (es de un solo uso) sin cambiar el
  /// alcance que eligió el usuario al iniciar sesión.
  Future<void> replaceRefreshToken(String refreshToken);

  /// Borra el token de la pestaña y, si la sesión persistente es la suya,
  /// también ese.
  Future<void> clear();
}
