import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('index.html da de baja service workers viejos antes de cargar la app',
      () {
    final html = File('web/index.html').readAsStringSync();
    final cleanup = html.indexOf('serviceWorker.getRegistrations()');
    expect(cleanup, greaterThan(0));
    expect(html, contains('r.unregister()'));
    expect(html, contains('caches.delete'));
    // Recarga una sola vez por pestaña para no entrar en bucle.
    expect(html, contains("sessionStorage.getItem('fixia-sw-cleared')"));
    expect(cleanup, lessThan(html.indexOf('flutter_bootstrap.js')));
  });
}
