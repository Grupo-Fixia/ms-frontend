import '../domain/auth_exceptions.dart';
import 'ports/auth_repository.dart';
import 'ports/session_storage.dart';
import 'session_store.dart';

/// Caso de uso: iniciar sesión (GC-236, RF-004).
///
/// Autentica, consulta el perfil con el access token recibido y guarda la
/// sesión. Si el perfil no se puede leer no queda sesión a medias: se
/// intenta cerrar la que se acaba de abrir.
///
/// Con `rememberSession` guarda el refresh token para restaurar la sesión al
/// reabrir la app; sin él se descarta cualquier token guardado antes.
class LoginUser {
  const LoginUser(this._repository, this._store, this._storage);

  final AuthRepository _repository;
  final SessionStore _store;
  final SessionStorage _storage;

  Future<void> call({
    required String email,
    required String password,
    bool rememberSession = false,
  }) async {
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
    await _persist(session.refreshToken, rememberSession);
  }

  /// Si el navegador no deja guardar (modo privado, almacenamiento lleno) el
  /// login igual vale: solo se pierde la persistencia. Se atrapa todo porque en
  /// web el almacenamiento falla con errores de JavaScript que no son
  /// `Exception`.
  Future<void> _persist(String refreshToken, bool remember) async {
    try {
      if (remember) {
        await _storage.saveRefreshToken(refreshToken);
      } else {
        await _storage.clear();
      }
    } catch (_) {
      // La sesión en memoria ya está iniciada.
    }
  }
}
