import '../domain/auth_exceptions.dart';
import 'ports/auth_repository.dart';
import 'session_store.dart';

/// Caso de uso: iniciar sesión (GC-236, RF-004).
///
/// Autentica, consulta el perfil con el access token recibido y guarda la
/// sesión. Si el perfil no se puede leer no queda sesión a medias: se
/// intenta cerrar la que se acaba de abrir.
class LoginUser {
  const LoginUser(this._repository, this._store);

  final AuthRepository _repository;
  final SessionStore _store;

  Future<void> call({required String email, required String password}) async {
    final session = await _repository.login(email: email, password: password);
    try {
      final profile = await _repository.fetchProfile(session.accessToken);
      _store.start(session, profile);
    } on AuthFailure {
      try {
        await _repository.logout(session);
      } on AuthFailure {
        // Sin sesión local no hay nada más que limpiar.
      }
      rethrow;
    }
  }
}
