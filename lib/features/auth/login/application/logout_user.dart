import '../domain/auth_exceptions.dart';
import '../domain/auth_session.dart';
import 'ports/auth_repository.dart';
import 'ports/session_storage.dart';
import 'session_store.dart';

/// Caso de uso: cerrar sesión (GC-236, RF-005).
///
/// La sesión local y el token guardado se descartan siempre, aunque el
/// backend no responda: el usuario debe poder salir.
class LogoutUser {
  const LogoutUser(this._repository, this._store, this._storage);

  final AuthRepository _repository;
  final SessionStore _store;
  final SessionStorage _storage;

  Future<void> call() async {
    final session = _store.session;
    try {
      if (session != null) await _revokeOnServer(session);
    } finally {
      _store.clear();
      try {
        await _storage.clear();
      } catch (_) {
        // Nada más que hacer si el navegador no deja borrar.
      }
    }
  }

  /// Revoca los tokens en ms-users. El access token dura 15 minutos: si ya
  /// venció (401), se renueva con el refresh token para poder revocar también
  /// ese refresh token en el backend; si no, quedaría válido hasta expirar.
  Future<void> _revokeOnServer(AuthSession session) async {
    try {
      await _repository.logout(session);
    } on AuthFailure catch (failure) {
      if (!failure.isUnauthorized) return; // Falla de red: vence solo.
      try {
        final renewed = await _repository.refresh(session.refreshToken);
        await _repository.logout(renewed);
      } on AuthFailure {
        // El refresh token tampoco sirve: no queda nada que revocar.
      }
    }
  }
}
