import 'package:web/web.dart' as web;

import 'key_value_store.dart';

/// `window.sessionStorage`: dura lo que dura la pestaña.
KeyValueStore tabKeyValueStore() =>
    _WebStorage(() => web.window.sessionStorage);

/// `window.localStorage`: sobrevive a cerrar el navegador.
KeyValueStore persistentKeyValueStore() =>
    _WebStorage(() => web.window.localStorage);

/// El almacenamiento se pide en cada operación y no al crear la app: si el
/// navegador lo bloquea (cookies bloqueadas, iframes, algunos modos
/// privados), el acceso lanza un error que los casos de uso atrapan, en vez
/// de impedir que la app arranque.
class _WebStorage implements KeyValueStore {
  const _WebStorage(this._storage);

  final web.Storage Function() _storage;

  @override
  String? read(String key) => _storage().getItem(key);

  @override
  void write(String key, String value) => _storage().setItem(key, value);

  @override
  void remove(String key) => _storage().removeItem(key);
}
