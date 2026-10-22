import 'package:flutter/foundation.dart';

import '../domain/auth_session.dart';
import '../domain/user_profile.dart';

/// Sesión activa de la app, en memoria. Es el punto único que consultan la
/// navegación y las pantallas autenticadas. Al recargar la página se
/// reconstruye con `RestoreSession` a partir del token guardado (GC-394).
class SessionStore extends ChangeNotifier {
  AuthSession? _session;
  UserProfile? _profile;
  Future<bool>? _renewal;

  AuthSession? get session => _session;
  UserProfile? get profile => _profile;
  bool get isAuthenticated => _session != null && _profile != null;

  /// Renovación en curso, o `null` si no hay ninguna. Cerrar sesión la espera
  /// para revocar el token más nuevo.
  Future<bool>? get pendingRenewal => _renewal;

  void start(AuthSession session, UserProfile profile) {
    _session = session;
    _profile = profile;
    notifyListeners();
  }

  /// Ejecuta [renew] si no hay otra renovación en curso; si la hay, devuelve
  /// la misma. El refresh token es de un solo uso: dos renovaciones a la vez
  /// harían que la segunda falle y cierre la sesión.
  Future<bool> renewOnce(Future<bool> Function() renew) {
    final pending = _renewal;
    if (pending != null) return pending;
    final renewal = renew();
    _renewal = renewal;
    renewal.whenComplete(() {
      if (identical(_renewal, renewal)) _renewal = null;
    }).ignore();
    return renewal;
  }

  void clear() {
    if (_session == null && _profile == null) return;
    _session = null;
    _profile = null;
    notifyListeners();
  }
}
