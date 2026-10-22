import 'dart:math';

import '../application/ports/session_storage.dart';
import 'key_value_store.dart';

/// Guarda el refresh token en el navegador (GC-394): siempre en
/// `sessionStorage` y, con "Mantener sesión iniciada", también en
/// `localStorage`.
///
/// Cada inicio de sesión con "Mantener sesión iniciada" recibe un id que se
/// guarda junto al token en `localStorage` y en la pestaña. Una pestaña solo
/// usa, renueva o borra el token persistente si el id es el suyo: así, con
/// dos cuentas abiertas en el mismo navegador (por ejemplo un cliente y un
/// técnico en pestañas distintas), ninguna toma ni pisa la sesión de la otra.
/// Las pestañas de la misma sesión comparten el id y siguen compartiendo el
/// token más nuevo.
///
/// Los errores del navegador (modo privado, almacenamiento bloqueado o lleno)
/// se propagan: los casos de uso los atrapan y la sesión sigue en memoria.
class BrowserSessionStorage implements SessionStorage {
  BrowserSessionStorage({
    required KeyValueStore tab,
    required KeyValueStore persistent,
    String Function()? newSessionId,
  })  : _tab = tab,
        _persistent = persistent,
        _newSessionId = newSessionId ?? _randomId;

  final KeyValueStore _tab;
  final KeyValueStore _persistent;
  final String Function() _newSessionId;

  static const key = 'fixia.refresh_token';
  static const sessionIdKey = 'fixia.session_id';

  /// - Si la pestaña pertenece a la sesión persistente, usa el token
  ///   persistente: lo comparten sus pestañas y cada renovación lo reemplaza,
  ///   así que es el más nuevo.
  /// - Si la pestaña tiene su propia sesión, usa la suya aunque en
  ///   `localStorage` haya otra (de otra cuenta o de otro inicio de sesión).
  /// - Si la pestaña no tiene sesión (pestaña nueva), se une a la persistente.
  @override
  Future<String?> readRefreshToken() async {
    final persisted = _nonEmpty(_persistent.read(key));
    final String? own;
    try {
      own = _nonEmpty(_tab.read(key));
    } catch (_) {
      // Sin sessionStorage la pestaña no tiene sesión propia.
      if (persisted != null) return persisted;
      rethrow;
    }
    if (own != null) {
      return persisted != null && _ownsPersistent() ? persisted : own;
    }
    if (persisted == null) return null;
    _joinPersistent();
    return persisted;
  }

  @override
  Future<void> saveRefreshToken(
    String refreshToken, {
    bool persist = false,
  }) async {
    final owned = _ownsPersistent();
    _tab.write(key, refreshToken);
    if (persist) {
      final id = _newSessionId();
      _tab.write(sessionIdKey, id);
      _persistent.write(key, refreshToken);
      _persistent.write(sessionIdKey, id);
      return;
    }
    _tab.remove(sessionIdKey);
    // Solo se olvida la sesión recordada si era de esta pestaña: la de otra
    // pestaña sigue siendo suya.
    if (owned) _removePersistent();
  }

  @override
  Future<void> replaceRefreshToken(String refreshToken) async {
    final owned = _ownsPersistent();
    _tab.write(key, refreshToken);
    if (owned && _nonEmpty(_persistent.read(key)) != null) {
      _persistent.write(key, refreshToken);
    }
  }

  @override
  Future<void> clear() async {
    // Si no se puede leer la pestaña, la sesión que conocía era la
    // persistente.
    final owned = _ownsPersistent(ifUnreadable: true);
    // Si un alcance falla, igual se intenta borrar el otro.
    try {
      _tab.remove(key);
      _tab.remove(sessionIdKey);
    } finally {
      if (owned) _removePersistent();
    }
  }

  bool _ownsPersistent({bool ifUnreadable = false}) {
    final String? mine;
    try {
      mine = _tab.read(sessionIdKey);
    } catch (_) {
      if (ifUnreadable) return true;
      rethrow;
    }
    return mine != null && mine == _persistent.read(sessionIdKey);
  }

  /// Una pestaña nueva adopta la sesión persistente (y le da id si se guardó
  /// antes de que existieran los ids).
  void _joinPersistent() {
    var id = _persistent.read(sessionIdKey);
    if (id == null || id.isEmpty) {
      id = _newSessionId();
      _persistent.write(sessionIdKey, id);
    }
    _tab.write(sessionIdKey, id);
  }

  void _removePersistent() {
    try {
      _persistent.remove(key);
    } finally {
      _persistent.remove(sessionIdKey);
    }
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  static final Random _random = Random();

  static String _randomId() {
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise = _random.nextInt(0x3fffffff).toRadixString(36);
    return '$micros-$noise';
  }
}
