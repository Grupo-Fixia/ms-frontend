import '../domain/auth_exceptions.dart';
import 'ports/auth_repository.dart';
import 'ports/session_storage.dart';
import 'session_store.dart';

/// Caso de uso: restaurar la sesión al abrir o recargar la app (GC-394).
///
/// Usa el refresh token guardado con "Mantener sesión iniciada" (el más
/// nuevo, compartido por todas las pestañas) o, si no hay, el de la pestaña
/// (recarga con F5).
///
/// Canjea el refresh token guardado por una sesión nueva y guarda de inmediato
/// el refresh token que lo reemplaza, porque el anterior queda revocado.
///
/// Si el token falla con 401 solo se borra si sigue siendo el guardado: si
/// otra pestaña ya lo reemplazó por uno nuevo, se intenta una vez con ese y,
/// si tampoco sirve, se conserva para no cerrar la sesión de las demás.
/// Devuelve `true` si la sesión quedó restaurada; nunca lanza.
class RestoreSession {
  const RestoreSession(this._repository, this._store, this._storage);

  final AuthRepository _repository;
  final SessionStore _store;
  final SessionStorage _storage;

  Future<bool> call() async {
    final stored = await _readQuietly();
    if (stored == null) return false;
    final first = await _restoreWith(stored);
    if (first.outcome != _Outcome.unauthorized) {
      return first.outcome == _Outcome.restored;
    }

    // Otra pestaña pudo haber renovado el token mientras tanto: el guardado
    // solo se borra si sigue siendo el que falló (o el que esta pestaña
    // acaba de escribir).
    final latest = await _readQuietly();
    if (latest == null) return false;
    if (latest == stored || latest == first.written) {
      await _clearQuietly();
      return false;
    }
    final second = await _restoreWith(latest);
    if (second.outcome == _Outcome.unauthorized) {
      final now = await _readQuietly();
      if (now == latest || now == second.written) await _clearQuietly();
    }
    return second.outcome == _Outcome.restored;
  }

  Future<({_Outcome outcome, String? written})> _restoreWith(
    String refreshToken,
  ) async {
    String? written;
    try {
      final session = await _repository.refresh(refreshToken);
      written = session.refreshToken;
      await _storage.replaceRefreshToken(written);
      final profile = await _repository.fetchProfile(session.accessToken);
      _store.start(session, profile);
      return (outcome: _Outcome.restored, written: written);
    } on AuthFailure catch (failure) {
      // Con 401 el token ya no sirve (vencido, usado o revocado). Si fue la
      // red, se conserva para reintentar la próxima vez.
      return (
        outcome:
            failure.isUnauthorized ? _Outcome.unauthorized : _Outcome.failed,
        written: written,
      );
    } catch (_) {
      return (outcome: _Outcome.failed, written: written);
    }
  }

  Future<String?> _readQuietly() async {
    try {
      final token = await _storage.readRefreshToken();
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      return null;
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

enum _Outcome { restored, unauthorized, failed }
