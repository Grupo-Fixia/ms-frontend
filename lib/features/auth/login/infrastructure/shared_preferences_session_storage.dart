import 'package:shared_preferences/shared_preferences.dart';

import '../application/ports/session_storage.dart';

/// Guarda el refresh token en el almacenamiento del navegador
/// (`localStorage` en web, vía `shared_preferences`).
class SharedPreferencesSessionStorage implements SessionStorage {
  SharedPreferencesSessionStorage(this._preferences);

  final SharedPreferences _preferences;

  static const _key = 'fixia.refresh_token';

  @override
  Future<String?> readRefreshToken() async => _preferences.getString(_key);

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    await _preferences.setString(_key, refreshToken);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_key);
  }
}
