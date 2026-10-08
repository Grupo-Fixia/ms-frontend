import '../domain/auth_exceptions.dart';
import 'ports/auth_repository.dart';
import 'ports/session_storage.dart';
import 'session_store.dart';

/// Caso de uso: restaurar la sesión al abrir la app (opción "Mantener sesión
/// iniciada").
///
/// Canjea el refresh token guardado por una sesión nueva y guarda de inmediato
/// el refresh token que lo reemplaza, porque el anterior queda revocado.
/// Devuelve `true` si la sesión quedó restaurada; nunca lanza.
class RestoreSession {
  const RestoreSession(this._repository, this._store, this._storage);

  final AuthRepository _repository;
  final SessionStore _store;
  final SessionStorage _storage;

  Future<bool> call() async {
    final String? stored;
    try {
      stored = await _storage.readRefreshToken();
    } catch (_) {
      return false;
    }
    if (stored == null || stored.isEmpty) return false;

    try {
      final session = await _repository.refresh(stored);
      await _storage.saveRefreshToken(session.refreshToken);
      final profile = await _repository.fetchProfile(session.accessToken);
      _store.start(session, profile);
      return true;
    } on AuthFailure catch (failure) {
      // Con 401 el token ya no sirve (vencido, usado o revocado): se borra.
      // Si fue la red, se conserva para reintentar la próxima vez.
      if (failure.isUnauthorized) await _clearQuietly();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearQuietly() async {
    try {
      await _storage.clear();
    } catch (_) {
      // Nada más que hacer.
    }
  }
}
