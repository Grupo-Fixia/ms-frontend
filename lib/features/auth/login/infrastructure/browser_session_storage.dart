import 'dart:math';

import '../application/ports/session_storage.dart';
import 'key_value_store.dart';
import 'open_tabs.dart';

/// Guarda el refresh token en el navegador (GC-394) para que la sesión sea
/// una sola en todo el navegador, como en cualquier página:
///
/// - **Compartido** (`localStorage`): el token, el id de la sesión y si se
///   eligió "Mantener sesión iniciada". Lo ven todas las pestañas: una
///   pestaña nueva entra directo a la cuenta ya iniciada.
/// - **Sin "Mantener sesión iniciada"** la sesión dura mientras quede abierta
///   alguna pestaña de Fixia ([OpenTabs]). Además, una cookie de sesión (sin
///   fecha de vencimiento, que el navegador borra al cerrarse) guarda solo el
///   id de la sesión, nunca el token: si el navegador se cerró, la sesión ya
///   no vale aunque el token siga en `localStorage`.
/// - **Pestaña** (`sessionStorage`): copia del token y del id de la sesión a
///   la que pertenece la pestaña. Sirve de respaldo si el navegador no deja
///   compartir (por ejemplo, cookies o `localStorage` bloqueados).
///
/// Las pestañas de la misma sesión comparten el token más nuevo: el refresh
/// token es de un solo uso y cada renovación lo reemplaza. Una pestaña solo
/// reemplaza o borra el compartido si es de su sesión.
///
/// Los errores del navegador (modo privado, almacenamiento bloqueado o lleno)
/// se propagan: los casos de uso los atrapan y la sesión sigue en memoria.
class BrowserSessionStorage implements SessionStorage {
  BrowserSessionStorage({
    required KeyValueStore tab,
    required KeyValueStore shared,
    required KeyValueStore browserSession,
    OpenTabs? openTabs,
    String Function()? newSessionId,
  })  : _tab = tab,
        _shared = shared,
        _browserSession = browserSession,
        _openTabs = openTabs,
        _newSessionId = newSessionId ?? _randomId;

  final KeyValueStore _tab;
  final KeyValueStore _shared;
  final KeyValueStore _browserSession;

  /// Si es `null` no se mira qué pestañas siguen abiertas (pruebas).
  final OpenTabs? _openTabs;
  final String Function() _newSessionId;

  static const key = 'fixia.refresh_token';
  static const sessionIdKey = 'fixia.session_id';
  static const rememberKey = 'fixia.remember_session';

  /// Nombre de la cookie con el id de la sesión mientras el navegador siga
  /// abierto.
  static const browserSessionKey = 'fixia_session';

  /// La sesión compartida del navegador si la hay (y la pestaña pasa a ser
  /// de esa sesión); si no, la copia de la pestaña.
  @override
  Future<String?> readRefreshToken() async {
    final shared = _readShared();
    if (shared != null) {
      _joinQuietly(shared.id);
      return shared.token;
    }
    final own = _nonEmpty(_tab.read(key));
    return own;
  }

  @override
  Future<void> saveRefreshToken(
    String refreshToken, {
    bool persist = false,
  }) async {
    final id = _newSessionId();
    _tab.write(key, refreshToken);
    _tab.write(sessionIdKey, id);
    if (!persist && !_markBrowserSession(id)) {
      // Sin cookie no se sabría cuándo se cerró el navegador: la sesión se
      // queda solo en esta pestaña.
      _removeShared();
      return;
    }
    _shared.write(key, refreshToken);
    _shared.write(sessionIdKey, id);
    _shared.write(rememberKey, persist ? '1' : '0');
  }

  @override
  Future<void> replaceRefreshToken(String refreshToken) async {
    if (_ownsShared(ifTabUnreadable: true)) _shared.write(key, refreshToken);
    _tab.write(key, refreshToken);
  }

  @override
  Future<void> clear() async {
    final owned = _ownsShared(ifTabUnreadable: true);
    // Si un alcance falla, igual se intenta borrar el otro.
    try {
      _tab.remove(key);
      _tab.remove(sessionIdKey);
    } finally {
      if (owned) _removeShared();
    }
  }

  @override
  Future<void> discardStaleTabCopy() async {
    final shared = _nonEmpty(_shared.read(sessionIdKey));
    final mine = _nonEmpty(_tab.read(sessionIdKey));
    if (mine == shared) return; // Es la misma sesión, o ninguna es compartida.
    _tab.remove(key);
    _tab.remove(sessionIdKey);
  }

  /// La sesión compartida vigente. Sin "Mantener sesión iniciada" se descarta
  /// si el navegador se cerró (ya no está la cookie) o si se cerraron todas
  /// sus pestañas; recargar la pestaña (F5) no la descarta.
  ({String token, String id})? _readShared() {
    final token = _nonEmpty(_shared.read(key));
    if (token == null) return null;
    var id = _nonEmpty(_shared.read(sessionIdKey));
    if (id == null) {
      // Guardada por una versión anterior, que solo compartía con "Mantener
      // sesión iniciada".
      id = _newSessionId();
      _shared.write(sessionIdKey, id);
      _shared.write(rememberKey, '1');
      return (token: token, id: id);
    }
    if (_shared.read(rememberKey) != '1' &&
        (_readBrowserSession() != id || !_tabsStillOpen(id))) {
      _removeShared();
      return null;
    }
    return (token: token, id: id);
  }

  /// Esta pestaña es de la sesión (se está recargando) o queda otra abierta.
  bool _tabsStillOpen(String id) {
    final openTabs = _openTabs;
    if (openTabs == null) return true;
    try {
      if (_tab.read(sessionIdKey) == id) return true;
    } catch (_) {
      // Sin `sessionStorage` se decide por las demás pestañas.
    }
    try {
      return openTabs.anyOtherAlive();
    } catch (_) {
      return true; // Si no se puede saber, no se cierra la sesión.
    }
  }

  bool _ownsShared({bool ifTabUnreadable = false}) {
    final shared = _nonEmpty(_shared.read(sessionIdKey));
    if (shared == null) return false;
    try {
      return _tab.read(sessionIdKey) == shared;
    } catch (_) {
      // Sin `sessionStorage` la pestaña solo pudo usar la compartida.
      if (ifTabUnreadable) return true;
      rethrow;
    }
  }

  void _joinQuietly(String id) {
    try {
      _tab.write(sessionIdKey, id);
    } catch (_) {
      // Sin `sessionStorage` igual se usa la compartida.
    }
  }

  /// Escribe la cookie y confirma que el navegador la guardó.
  bool _markBrowserSession(String id) {
    try {
      _browserSession.write(browserSessionKey, id);
      return _browserSession.read(browserSessionKey) == id;
    } catch (_) {
      return false;
    }
  }

  String? _readBrowserSession() {
    try {
      return _browserSession.read(browserSessionKey);
    } catch (_) {
      return null;
    }
  }

  void _removeShared() {
    try {
      _shared.remove(key);
      _shared.remove(sessionIdKey);
      _shared.remove(rememberKey);
    } finally {
      try {
        _browserSession.remove(browserSessionKey);
      } catch (_) {
        // Si no se puede borrar, la borra el navegador al cerrarse.
      }
    }
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  static final Random _random = Random();

  /// En web los enteros son de JavaScript: el máximo se mantiene por debajo
  /// de 2^31.
  static String _randomId() {
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise = _random.nextInt(0x3fffffff).toRadixString(36);
    return '$micros-$noise';
  }
}
