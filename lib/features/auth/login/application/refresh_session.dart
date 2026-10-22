import '../domain/auth_exceptions.dart';
import '../domain/user_profile.dart';
import 'ports/auth_repository.dart';
import 'ports/session_storage.dart';
import 'session_store.dart';

/// Caso de uso: renovar la sesión cuando el access token venció (dura 15
/// minutos) para reintentar la llamada que falló con 401.
///
/// El refresh token es de un solo uso: se reemplaza en la sesión y en el
/// almacenamiento, en el mismo alcance que eligió el usuario al iniciar sesión.
///
/// - Si varias llamadas piden renovar a la vez, se hace una sola renovación y
///   todas esperan ese resultado (`SessionStore.renewOnce`).
/// - Si el token de la sesión ya fue usado por otra pestaña ("Mantener sesión
///   iniciada"), se reintenta con el guardado, que es el más nuevo, siempre
///   que sea de la misma cuenta.
///
/// Devuelve `true` si la sesión quedó renovada; nunca lanza.
class RefreshSession {
  const RefreshSession(this._repository, this._store, this._storage);

  final AuthRepository _repository;
  final SessionStore _store;
  final SessionStorage _storage;

  Future<bool> call() => _store.renewOnce(_renew);

  Future<bool> _renew() async {
    final session = _store.session;
    final profile = _store.profile;
    if (session == null || profile == null) return false;
    try {
      final renewed = await _repository.refresh(session.refreshToken);
      _store.start(renewed, profile);
      await _replaceStoredToken(renewed.refreshToken);
      return true;
    } on AuthFailure catch (failure) {
      if (!failure.isUnauthorized) return false;
      return _renewWithStoredToken(session.refreshToken, profile);
    } catch (_) {
      return false;
    }
  }

  /// Otra pestaña pudo haber renovado y guardado un token más nuevo.
  Future<bool> _renewWithStoredToken(String used, UserProfile profile) async {
    try {
      final stored = await _storage.readRefreshToken();
      if (stored == null || stored.isEmpty || stored == used) return false;
      final renewed = await _repository.refresh(stored);
      final current = await _repository.fetchProfile(renewed.accessToken);
      // El almacenamiento es del navegador: si en otra pestaña se inició
      // sesión con otra cuenta, no se mezcla con esta.
      if (current.id != profile.id) return false;
      _store.start(renewed, current);
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
