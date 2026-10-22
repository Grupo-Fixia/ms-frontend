import '../../../../core/http/authorized_http.dart';
import '../domain/auth_exceptions.dart';
import '../domain/auth_session.dart';
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
/// - Si mientras se renovaba se cerró sesión (o se inició otra), el
///   resultado se descarta: no revive la sesión ni escribe en el navegador.
class RefreshSession {
  const RefreshSession(this._repository, this._store, this._storage);

  final AuthRepository _repository;
  final SessionStore _store;
  final SessionStorage _storage;

  /// `true` si la sesión quedó renovada; `false` si venció o no se pudo
  /// renovar por cualquier motivo. Nunca lanza.
  Future<bool> call() async {
    try {
      return await renew();
    } catch (_) {
      return false;
    }
  }

  /// Para las llamadas HTTP: `true` si quedó renovada y `false` si la sesión
  /// venció (hay que volver a iniciar sesión). Si no se pudo contactar al
  /// backend (sin red, tiempo agotado o error del servidor) lanza
  /// [BackendUnreachableException]: la sesión puede seguir siendo válida y no
  /// hay que sacar al usuario.
  Future<bool> renew() => _store.renewOnce(_renew);

  Future<bool> _renew() async {
    final session = _store.session;
    final profile = _store.profile;
    if (session == null || profile == null) return false;
    final AuthSession renewed;
    try {
      renewed = await _repository.refresh(session.refreshToken);
    } on AuthFailure catch (failure) {
      if (!failure.isUnauthorized) throw const BackendUnreachableException();
      return _renewWithStoredToken(session, profile);
    }
    if (!identical(_store.session, session)) return _changedMeanwhile();
    _store.start(renewed, profile);
    await _replaceStoredToken(renewed.refreshToken);
    return true;
  }

  /// Otra pestaña pudo haber renovado y guardado un token más nuevo.
  Future<bool> _renewWithStoredToken(
    AuthSession session,
    UserProfile profile,
  ) async {
    final stored = await _readStoredToken();
    if (stored == null || stored == session.refreshToken) return false;

    final AuthSession renewed;
    try {
      renewed = await _repository.refresh(stored);
    } on AuthFailure catch (failure) {
      if (!failure.isUnauthorized) throw const BackendUnreachableException();
      return false;
    }
    // El guardado ya se gastó: hay que dejar su reemplazo en el navegador,
    // aunque resulte ser de otra cuenta, para no cerrar la sesión de las
    // demás pestañas.
    await _replaceStoredToken(renewed.refreshToken);

    final UserProfile current;
    try {
      current = await _repository.fetchProfile(renewed.accessToken);
    } on AuthFailure catch (failure) {
      if (!failure.isUnauthorized) throw const BackendUnreachableException();
      return false;
    }
    if (!identical(_store.session, session)) return _changedMeanwhile();
    // El almacenamiento es del navegador: si en otra pestaña se inició
    // sesión con otra cuenta, no se mezcla con esta.
    if (current.id != profile.id) return false;
    _store.start(renewed, current);
    return true;
  }

  /// Se cerró sesión (o se inició otra) mientras se renovaba.
  bool _changedMeanwhile() => _store.isAuthenticated;

  Future<String?> _readStoredToken() async {
    try {
      final token = await _storage.readRefreshToken();
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      return null;
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
