import '../domain/auth_exceptions.dart';
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
      if (session != null) await _repository.logout(session);
    } on AuthFailure {
      // El token vence solo; igual se limpia la sesión local.
    } finally {
      _store.clear();
      try {
        await _storage.clear();
      } catch (_) {
        // Nada más que hacer si el navegador no deja borrar.
      }
    }
  }
}
