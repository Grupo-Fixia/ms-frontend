import 'dart:math';

import 'key_value_store.dart';

/// Pestañas de Fixia abiertas en el navegador (GC-394).
///
/// Sin "Mantener sesión iniciada", la sesión dura mientras quede abierta
/// alguna pestaña de Fixia: cada pestaña deja una señal de vida en
/// `localStorage`, la renueva cada [heartbeat] y la borra al cerrarse. Si una
/// pestaña se cierra sin avisar (el navegador se cuelga), su señal deja de
/// contar pasado [timeout]. El navegador puede espaciar los temporizadores
/// de las pestañas en segundo plano hasta un minuto: por eso [timeout] es
/// mayor.
class OpenTabs {
  OpenTabs(
    this._store, {
    DateTime Function()? now,
    String? tabId,
  })  : _now = now ?? DateTime.now,
        _key = '$prefix${tabId ?? _randomId()}';

  final ListableKeyValueStore _store;
  final DateTime Function() _now;
  final String _key;

  static const prefix = 'fixia.tab.';
  static const heartbeat = Duration(seconds: 15);
  static const timeout = Duration(seconds: 90);

  /// Hay otra pestaña abierta (sin contar esta). Las señales vencidas se
  /// borran de paso.
  bool anyOtherAlive() {
    final now = _now().millisecondsSinceEpoch;
    var alive = false;
    for (final key in _store.keysStartingWith(prefix)) {
      if (key == _key) continue;
      final seen = int.tryParse(_store.read(key) ?? '');
      if (seen != null && now - seen <= timeout.inMilliseconds) {
        alive = true;
      } else {
        _store.remove(key);
      }
    }
    return alive;
  }

  /// Esta pestaña sigue abierta.
  void markAlive() => _store.write(_key, '${_now().millisecondsSinceEpoch}');

  /// Esta pestaña se cierra (o se recarga: al volver, avisa de nuevo).
  void markClosed() => _store.remove(_key);

  static final Random _random = Random();

  static String _randomId() {
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$micros-${_random.nextInt(0x3fffffff).toRadixString(36)}';
  }
}
