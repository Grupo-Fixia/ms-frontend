@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_key_value_store.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_session_storage.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/key_value_store.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/open_tabs.dart';

void main() {
  test('en el navegador usa sessionStorage y localStorage reales', () async {
    final tab = tabKeyValueStore();
    final local = persistentKeyValueStore();
    final storage = BrowserSessionStorage(
      tab: tab,
      shared: local,
      browserSession: browserSessionKeyValueStore(),
    );

    await storage.saveRefreshToken('r1', persist: true);
    expect(tab.read(BrowserSessionStorage.key), 'r1');
    expect(local.read(BrowserSessionStorage.key), 'r1');

    await storage.replaceRefreshToken('r2');
    expect(await storage.readRefreshToken(), 'r2');

    await storage.clear();
    expect(await storage.readRefreshToken(), isNull);
  });

  test('sin "Mantener" la sesión se comparte con una cookie de sesión',
      () async {
    final cookies = browserSessionKeyValueStore();
    final storage = BrowserSessionStorage(
      tab: tabKeyValueStore(),
      shared: persistentKeyValueStore(),
      browserSession: cookies,
    );

    await storage.saveRefreshToken('r1');
    final id = cookies.read(BrowserSessionStorage.browserSessionKey);
    expect(id, isNotNull);
    expect(id, isNot(contains('r1')), reason: 'la cookie no lleva el token');

    // Otra pestaña: su propio sessionStorage, el mismo navegador.
    final otherTab = BrowserSessionStorage(
      tab: InMemoryKeyValueStore(),
      shared: persistentKeyValueStore(),
      browserSession: browserSessionKeyValueStore(),
    );
    expect(await otherTab.readRefreshToken(), 'r1');

    await otherTab.clear();
    expect(cookies.read(BrowserSessionStorage.browserSessionKey), isNull);
    expect(await storage.readRefreshToken(), 'r1',
        reason: 'solo queda la copia de la pestaña');
    await storage.clear();
    expect(await storage.readRefreshToken(), isNull);
  });

  test('en el navegador las pestañas abiertas se ven en localStorage', () {
    final local = persistentKeyValueStore();
    final a = OpenTabs(local, tabId: 'a')..markAlive();
    final b = OpenTabs(local, tabId: 'b');

    expect(local.keysStartingWith(OpenTabs.prefix), contains('fixia.tab.a'));
    expect(b.anyOtherAlive(), isTrue);
    a.markClosed();
    expect(b.anyOtherAlive(), isFalse);
    expect(() => onTabClosed(() {}, () {}), returnsNormally);
  });

  test('crear los almacenes no toca el navegador hasta usarlos', () {
    // Si el navegador bloqueara el almacenamiento, el error saldría al leer
    // (y lo atrapan los casos de uso), no al arrancar la app.
    expect(tabKeyValueStore, returnsNormally);
    expect(persistentKeyValueStore, returnsNormally);
  });
}
