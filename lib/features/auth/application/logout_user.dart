import '../domain/auth_exceptions.dart';
import 'ports/auth_repository.dart';
import 'session_store.dart';

/// Caso de uso: cerrar sesión (GC-236, RF-005).
///
/// La sesión local se descarta siempre, aunque el backend no responda:
/// el usuario debe poder salir.
class LogoutUser {
  const LogoutUser(this._repository, this._store);

  final AuthRepository _repository;
  final SessionStore _store;

  Future<void> call() async {
    final session = _store.session;
    try {
      if (session != null) await _repository.logout(session);
    } on AuthFailure {
      // El token vence solo; igual se limpia la sesión local.
    } finally {
      _store.clear();
    }
  }
}
