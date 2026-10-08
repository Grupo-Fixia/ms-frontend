/// Puerto de salida: dónde se guarda el refresh token cuando el usuario pide
/// "Mantener sesión iniciada". El access token nunca se guarda.
abstract interface class SessionStorage {
  Future<String?> readRefreshToken();

  Future<void> saveRefreshToken(String refreshToken);

  Future<void> clear();
}
