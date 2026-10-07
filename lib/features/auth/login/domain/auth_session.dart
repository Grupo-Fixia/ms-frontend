/// Tokens de la sesión que devuelve `POST /api/users/auth/login`.
///
/// Solo viven en memoria (ver `SessionStore`).
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final Duration expiresIn;

  /// Evita que los tokens aparezcan en logs si el objeto se imprime.
  @override
  String toString() => 'AuthSession(expiresIn: $expiresIn)';
}
