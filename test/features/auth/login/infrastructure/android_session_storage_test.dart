import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_key_value_store_stub.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_session_storage.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/key_value_store.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/open_tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sesión en la app Android (GC-550): el almacén compartido vive en las
/// preferencias del dispositivo y lo demás en memoria, como en una pestaña.

/// Lo que crea la app al arrancar en Android.
BrowserSessionStorage _openApp(SharedPreferences preferences) {
  final shared = PreferencesKeyValueStore(preferences);
  return BrowserSessionStorage(
    tab: InMemoryKeyValueStore(),
    shared: shared,
    browserSession: InMemoryKeyValueStore(),
    openTabs: OpenTabs(PreferencesKeyValueStore(preferences)),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lee, escribe, borra y lista claves en las preferencias', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = PreferencesKeyValueStore(preferences)
      ..write('fixia.a', '1')
      ..write('fixia.b', '2')
      ..write('otra', '3');

    expect(store.read('fixia.a'), '1');
    expect(store.keysStartingWith('fixia.')..sort(), ['fixia.a', 'fixia.b']);
    store.remove('fixia.a');
    expect(store.read('fixia.a'), isNull);
    expect(preferences.getString('fixia.b'), '2');
  });

  test('«Mantener sesión iniciada» sobrevive a cerrar la app', () async {
    final preferences = await SharedPreferences.getInstance();
    await _openApp(preferences).saveRefreshToken('rt-1', persist: true);

    // Se cierra la app: la memoria se pierde, las preferencias no.
    final reopened = _openApp(preferences);
    expect(await reopened.readRefreshToken(), 'rt-1');
  });

  test('sin «Mantener sesión iniciada», cerrar la app cierra la sesión',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final open = _openApp(preferences);
    await open.saveRefreshToken('rt-1');
    expect(await open.readRefreshToken(), 'rt-1');

    final reopened = _openApp(preferences);
    expect(await reopened.readRefreshToken(), isNull);
  });

  test('cerrar sesión borra lo recordado', () async {
    final preferences = await SharedPreferences.getInstance();
    final open = _openApp(preferences);
    await open.saveRefreshToken('rt-1', persist: true);
    await open.clear();

    expect(await _openApp(preferences).readRefreshToken(), isNull);
  });

  test('fuera de Android el almacén persistente es memoria', () async {
    await initPersistentStorage();
    expect(persistentKeyValueStore(), isA<InMemoryKeyValueStore>());
  });
}
