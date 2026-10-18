import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_key_value_store.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_session_storage.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/key_value_store.dart';

/// Almacén que simula un navegador que bloquea el almacenamiento.
class _BlockedStore implements KeyValueStore {
  @override
  String? read(String key) => throw StateError('bloqueado');

  @override
  void write(String key, String value) => throw StateError('bloqueado');

  @override
  void remove(String key) => throw StateError('bloqueado');
}

void main() {
  const key = BrowserSessionStorage.key;
  late InMemoryKeyValueStore tab;
  late InMemoryKeyValueStore persistent;
  late BrowserSessionStorage storage;

  setUp(() {
    tab = InMemoryKeyValueStore();
    persistent = InMemoryKeyValueStore();
    storage = BrowserSessionStorage(tab: tab, persistent: persistent);
  });

  test('sin nada guardado no hay token', () async {
    expect(await storage.readRefreshToken(), isNull);
  });

  group('saveRefreshToken', () {
    test('sin persistir guarda solo en la pestaña (sessionStorage)', () async {
      await storage.saveRefreshToken('r1');

      expect(tab.read(key), 'r1');
      expect(persistent.read(key), isNull);
      expect(await storage.readRefreshToken(), 'r1');
    });

    test('sin persistir borra un token persistente de otra sesión', () async {
      persistent.write(key, 'viejo');

      await storage.saveRefreshToken('r1');

      expect(persistent.read(key), isNull);
    });

    test('persistiendo guarda en la pestaña y en localStorage', () async {
      await storage.saveRefreshToken('r1', persist: true);

      expect(tab.read(key), 'r1');
      expect(persistent.read(key), 'r1');
    });
  });

  group('readRefreshToken', () {
    test('prefiere el token de la pestaña', () async {
      tab.write(key, 'pestaña');
      persistent.write(key, 'persistente');

      expect(await storage.readRefreshToken(), 'pestaña');
    });

    test('en una pestaña nueva usa el persistente', () async {
      persistent.write(key, 'persistente');

      expect(await storage.readRefreshToken(), 'persistente');
    });

    test('ignora un token vacío en la pestaña', () async {
      tab.write(key, '');
      persistent.write(key, 'persistente');

      expect(await storage.readRefreshToken(), 'persistente');
    });
  });

  group('replaceRefreshToken', () {
    test('sesión solo de pestaña: no escribe en localStorage', () async {
      await storage.saveRefreshToken('r1');

      await storage.replaceRefreshToken('r2');

      expect(tab.read(key), 'r2');
      expect(persistent.read(key), isNull);
    });

    test('sesión persistente: actualiza ambos alcances', () async {
      await storage.saveRefreshToken('r1', persist: true);

      await storage.replaceRefreshToken('r2');

      expect(tab.read(key), 'r2');
      expect(persistent.read(key), 'r2');
    });
  });

  test('clear borra ambos alcances', () async {
    await storage.saveRefreshToken('r1', persist: true);

    await storage.clear();

    expect(tab.read(key), isNull);
    expect(persistent.read(key), isNull);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('clear borra localStorage aunque sessionStorage falle', () async {
    persistent.write(key, 'r1');
    final partial =
        BrowserSessionStorage(tab: _BlockedStore(), persistent: persistent);

    await expectLater(partial.clear(), throwsStateError);

    expect(persistent.read(key), isNull);
  });

  test('los errores del navegador llegan al caso de uso', () async {
    final blocked =
        BrowserSessionStorage(tab: _BlockedStore(), persistent: persistent);

    await expectLater(blocked.readRefreshToken(), throwsStateError);
    await expectLater(blocked.saveRefreshToken('r1'), throwsStateError);
  });

  test('fuera del navegador los almacenes son independientes y en memoria', () {
    final tabStore = tabKeyValueStore()..write(key, 'r1');
    final persistentStore = persistentKeyValueStore();

    expect(tabStore.read(key), 'r1');
    expect(persistentStore.read(key), isNull);
    tabStore.remove(key);
    expect(tabStore.read(key), isNull);
  });
}
