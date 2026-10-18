import '../application/ports/session_storage.dart';
import 'key_value_store.dart';

/// Guarda el refresh token en el navegador (GC-394): siempre en
/// `sessionStorage` y, con "Mantener sesión iniciada", también en
/// `localStorage`.
///
/// Los errores del navegador (modo privado, almacenamiento bloqueado o lleno)
/// se propagan: los casos de uso los atrapan y la sesión sigue en memoria.
class BrowserSessionStorage implements SessionStorage {
  BrowserSessionStorage({
    required KeyValueStore tab,
    required KeyValueStore persistent,
  })  : _tab = tab,
        _persistent = persistent;

  final KeyValueStore _tab;
  final KeyValueStore _persistent;

  static const key = 'fixia.refresh_token';

  @override
  Future<String?> readRefreshToken() async {
    final token = _tab.read(key);
    if (token != null && token.isNotEmpty) return token;
    return _persistent.read(key);
  }

  @override
  Future<void> saveRefreshToken(
    String refreshToken, {
    bool persist = false,
  }) async {
    _tab.write(key, refreshToken);
    if (persist) {
      _persistent.write(key, refreshToken);
    } else {
      _persistent.remove(key);
    }
  }

  @override
  Future<void> replaceRefreshToken(String refreshToken) async {
    _tab.write(key, refreshToken);
    final persisted = _persistent.read(key);
    if (persisted != null && persisted.isNotEmpty) {
      _persistent.write(key, refreshToken);
    }
  }

  @override
  Future<void> clear() async {
    // Si un alcance falla, igual se intenta borrar el otro.
    try {
      _tab.remove(key);
    } finally {
      _persistent.remove(key);
    }
  }
}
