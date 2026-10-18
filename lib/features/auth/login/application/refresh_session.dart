import 'ports/auth_repository.dart';
import 'ports/session_storage.dart';
import 'session_store.dart';

/// Caso de uso: renovar la sesión cuando el access token venció (dura 15
/// minutos) para reintentar la llamada que falló con 401.
///
/// El refresh token es de un solo uso: se reemplaza en la sesión y en el
/// almacenamiento, en el mismo alcance que eligió el usuario al iniciar sesión.
/// Devuelve `true` si la sesión quedó renovada; nunca lanza.
class RefreshSession {
  const RefreshSession(this._repository, this._store, this._storage);

  final AuthRepository _repository;
  final SessionStore _store;
  final SessionStorage _storage;

  Future<bool> call() async {
    final session = _store.session;
    final profile = _store.profile;
    if (session == null || profile == null) return false;
    try {
      final renewed = await _repository.refresh(session.refreshToken);
      _store.start(renewed, profile);
      await _replaceStoredToken(renewed.refreshToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _replaceStoredToken(String refreshToken) async {
    try {
      await _storage.replaceRefreshToken(refreshToken);
    } catch (_) {
      // Si el navegador no deja guardar, la sesión en memoria igual sirve.
    }
  }
}
