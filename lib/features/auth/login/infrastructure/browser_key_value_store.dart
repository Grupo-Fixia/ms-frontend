/// Almacenes del navegador. En web usa `window.sessionStorage`,
/// `window.localStorage` y cookies de sesión; fuera del navegador (pruebas)
/// usa memoria.
library;

export 'browser_key_value_store_stub.dart'
    if (dart.library.js_interop) 'browser_key_value_store_web.dart';
