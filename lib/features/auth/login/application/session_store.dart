import 'package:flutter/foundation.dart';

import '../domain/auth_session.dart';
import '../domain/user_profile.dart';

/// Sesión activa de la app. Solo en memoria: al recargar la página se pierde.
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
