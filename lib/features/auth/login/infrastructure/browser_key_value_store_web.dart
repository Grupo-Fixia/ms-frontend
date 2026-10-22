import 'package:web/web.dart' as web;

import 'key_value_store.dart';

/// `window.sessionStorage`: dura lo que dura la pestaña.
KeyValueStore tabKeyValueStore() =>
    _WebStorage(() => web.window.sessionStorage);

/// `window.localStorage`: lo comparten las pestañas y sobrevive a cerrar el
/// navegador.
ListableKeyValueStore persistentKeyValueStore() =>
    _WebStorage(() => web.window.localStorage);

/// Cookies de sesión (sin fecha de vencimiento): el navegador las borra al
/// cerrarse.
KeyValueStore browserSessionKeyValueStore() => const _SessionCookies();

/// Avisa cuando otra pestaña cambia la sesión compartida (inicia o cierra
/// sesión). El navegador no avisa a la pestaña que hizo el cambio.
Stream<void> sharedSessionChanges(String sessionIdKey) =>
    web.EventStreamProviders.storageEvent
        .forTarget(web.window)
        .where((event) => event.key == null || event.key == sessionIdKey);

/// Avisa cuando la pestaña se cierra o se recarga ([closed]) y cuando el
/// navegador la vuelve a mostrar desde su caché de historial ([reopened]).
void onTabClosed(void Function() closed, void Function() reopened) {
  web.EventStreamProviders.pageHideEvent
      .forTarget(web.window)
      .listen((_) => closed());
  web.EventStreamProviders.pageShowEvent
      .forTarget(web.window)
      .listen((_) => reopened());
}

/// El almacenamiento se pide en cada operación y no al crear la app: si el
/// navegador lo bloquea (cookies bloqueadas, iframes, algunos modos
/// privados), el acceso lanza un error que los casos de uso atrapan, en vez
/// de impedir que la app arranque.
class _WebStorage implements ListableKeyValueStore {
  const _WebStorage(this._storage);

  final web.Storage Function() _storage;

  @override
  List<String> keysStartingWith(String prefix) {
    final storage = _storage();
    return [
      for (var i = 0; i < storage.length; i++)
        if (storage.key(i) case final key? when key.startsWith(prefix)) key,
    ];
  }

  @override
  String? read(String key) => _storage().getItem(key);

  @override
  void write(String key, String value) => _storage().setItem(key, value);

  @override
  void remove(String key) => _storage().removeItem(key);
}

class _SessionCookies implements KeyValueStore {
  const _SessionCookies();

  @override
  String? read(String key) {
    for (final part in web.document.cookie.split(';')) {
      final cookie = part.trim();
      final separator = cookie.indexOf('=');
      if (separator <= 0) continue;
      if (cookie.substring(0, separator) == key) {
        return Uri.decodeComponent(cookie.substring(separator + 1));
      }
    }
    return null;
  }

  @override
  void write(String key, String value) => web.document.cookie =
      '$key=${Uri.encodeComponent(value)}; path=/; SameSite=Strict';

  @override
  void remove(String key) =>
      web.document.cookie = '$key=; path=/; max-age=0; SameSite=Strict';
}
