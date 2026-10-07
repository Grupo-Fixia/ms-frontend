import '../../domain/auth_session.dart';
import '../../domain/user_profile.dart';

/// Puerto de salida: cómo se habla con la API de autenticación de ms-users.
///
/// Todos los métodos lanzan `AuthFailure` si el backend rechaza la solicitud
/// o no se puede contactar.
abstract interface class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  /// Canjea un refresh token por una sesión nueva. El refresh token es de un
  /// solo uso: el recibido queda revocado y hay que guardar el nuevo.
  Future<AuthSession> refresh(String refreshToken);

  Future<UserProfile> fetchProfile(String accessToken);

  Future<void> logout(AuthSession session);
}
