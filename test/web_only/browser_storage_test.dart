@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_key_value_store.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_session_storage.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/key_value_store.dart';

void main() {
  test('en el navegador usa sessionStorage y localStorage reales', () async {
    final tab = tabKeyValueStore();
    final local = persistentKeyValueStore();
    final storage = BrowserSessionStorage(tab: tab, persistent: local);

    await storage.saveRefreshToken('r1', persist: true);
    expect(tab.read(BrowserSessionStorage.key), 'r1');
    expect(local.read(BrowserSessionStorage.key), 'r1');

    await storage.replaceRefreshToken('r2');
    expect(await storage.readRefreshToken(), 'r2');

    await storage.clear();
    expect(await storage.readRefreshToken(), isNull);
  });

  test('en el navegador dos cuentas en pestañas distintas no se mezclan',
      () async {
    final local = persistentKeyValueStore();
    final otherTab = InMemoryKeyValueStore();
    final remembered = BrowserSessionStorage(tab: otherTab, persistent: local);
    final ownTab =
        BrowserSessionStorage(tab: tabKeyValueStore(), persistent: local);

    await ownTab.saveRefreshToken('tecnico');
    await remembered.saveRefreshToken('cliente', persist: true);
    await ownTab.replaceRefreshToken('tecnico-2');

    expect(await ownTab.readRefreshToken(), 'tecnico-2');
    expect(await remembered.readRefreshToken(), 'cliente');

    await ownTab.clear();
    await remembered.clear();
    expect(local.read(BrowserSessionStorage.key), isNull);
  });

  test('crear los almacenes no toca el navegador hasta usarlos', () {
    // Si el navegador bloqueara el almacenamiento, el error saldría al leer
    // (y lo atrapan los casos de uso), no al arrancar la app.
    expect(tabKeyValueStore, returnsNormally);
    expect(persistentKeyValueStore, returnsNormally);
  });
}
