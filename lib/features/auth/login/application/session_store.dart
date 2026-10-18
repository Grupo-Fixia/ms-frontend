import 'package:flutter/foundation.dart';

import '../domain/auth_session.dart';
import '../domain/user_profile.dart';

/// Sesión activa de la app, en memoria. Es el punto único que consultan la
/// navegación y las pantallas autenticadas. Al recargar la página se
/// reconstruye con `RestoreSession` a partir del token guardado (GC-394).
class SessionStore extends ChangeNotifier {
  AuthSession? _session;
  UserProfile? _profile;

  AuthSession? get session => _session;
  UserProfile? get profile => _profile;
  bool get isAuthenticated => _session != null && _profile != null;

  void start(AuthSession session, UserProfile profile) {
    _session = session;
    _profile = profile;
    notifyListeners();
  }

  void clear() {
    if (_session == null && _profile == null) return;
    _session = null;
    _profile = null;
    notifyListeners();
  }
}
