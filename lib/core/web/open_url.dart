/// Abre una URL externa (por ejemplo, la descarga del APK). En web usa el
/// navegador; fuera de él (pruebas) no hace nada.
library;

export 'open_url_stub.dart' if (dart.library.js_interop) 'open_url_web.dart';
