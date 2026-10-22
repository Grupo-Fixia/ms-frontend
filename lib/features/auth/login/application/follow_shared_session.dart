import 'ports/auth_repository.dart';
import 'ports/session_storage.dart';
import 'restore_session.dart';
import 'session_store.dart';

/// Qué pasó con la sesión de esta pestaña al seguir a las demás.
enum SharedSessionChange {
  /// Sigue la misma cuenta.
  sameAccount,

  /// Ahora hay otra cuenta (se cerró sesión y se entró con otra).
  otherAccount,

  /// Ya no hay sesión: se cerró en otra pestaña.
  signedOut,
}

/// Caso de uso: seguir la sesión cuando otra pestaña inicia o cierra sesión
/// (GC-394). La sesión es una sola en todo el navegador: esta pestaña adopta
/// la que quedó guardada o, si no queda ninguna, también cierra la suya.
class FollowSharedSession {
  FollowSharedSession(this._repository, this._store, this._storage);

  final AuthRepository _repository;
  final SessionStore _store;
  final SessionStorage _storage;

  Future<SharedSessionChange>? _running;

  /// Si llegan varios avisos seguidos, se atienden uno detrás de otro.
  Future<SharedSessionChange> call() {
    final previous = _running;
    final next = () async {
      if (previous != null) await previous;
      return _follow();
    }();
    _running = next;
    next.whenComplete(() {
      if (identical(_running, next)) _running = null;
    }).ignore();
    return next;
  }

  Future<SharedSessionChange> _follow() async {
    try {
      await _store.pendingRenewal;
    } catch (_) {
      // Da igual cómo terminó la renovación.
    }
    final before = _store.profile;

    // Si la copia de esta pestaña es de la sesión anterior, ya no sirve.
    try {
      await _storage.discardStaleTabCopy();
    } catch (_) {
      // Si no se puede borrar, la sesión compartida igual va primero.
    }

    final next = SessionStore();
    final restored = await RestoreSession(_repository, next, _storage)();
    if (!restored) {
      _store.clear();
      return SharedSessionChange.signedOut;
    }
    _store.start(next.session!, next.profile!);
    next.dispose();
    return before != null && before.id == _store.profile!.id
        ? SharedSessionChange.sameAccount
        : SharedSessionChange.otherAccount;
  }
}
