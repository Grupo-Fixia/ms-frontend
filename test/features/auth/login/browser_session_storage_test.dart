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

    test('sin persistir olvida la sesión recordada por esta pestaña', () async {
      await storage.saveRefreshToken('viejo', persist: true);

      await storage.saveRefreshToken('r1');

      expect(persistent.read(key), isNull);
      expect(persistent.read(BrowserSessionStorage.sessionIdKey), isNull);
      expect(await storage.readRefreshToken(), 'r1');
    });

    test('sin persistir no borra la sesión recordada de otra pestaña',
        () async {
      persistent
        ..write(key, 'de-otra-pestaña')
        ..write(BrowserSessionStorage.sessionIdKey, 'otra');

      await storage.saveRefreshToken('r1');

      expect(persistent.read(key), 'de-otra-pestaña');
      expect(await storage.readRefreshToken(), 'r1');
    });

    test('cada inicio de sesión persistente tiene su propio id', () async {
      await storage.saveRefreshToken('r1', persist: true);
      final first = persistent.read(BrowserSessionStorage.sessionIdKey);
      await storage.saveRefreshToken('r2', persist: true);

      expect(first, isNotNull);
      expect(persistent.read(BrowserSessionStorage.sessionIdKey), isNot(first));
      expect(tab.read(BrowserSessionStorage.sessionIdKey),
          persistent.read(BrowserSessionStorage.sessionIdKey));
    });

    test('persistiendo guarda en la pestaña y en localStorage', () async {
      await storage.saveRefreshToken('r1', persist: true);

      expect(tab.read(key), 'r1');
      expect(persistent.read(key), 'r1');
    });
  });

  group('readRefreshToken', () {
    test('si la pestaña es de la sesión persistente, prefiere el persistente',
        () async {
      tab
        ..write(key, 'copia-vieja-de-la-pestaña')
        ..write(BrowserSessionStorage.sessionIdKey, 's1');
      persistent
        ..write(key, 'persistente')
        ..write(BrowserSessionStorage.sessionIdKey, 's1');

      expect(await storage.readRefreshToken(), 'persistente');
    });

    test('si el persistente es de otra sesión, usa el de la pestaña', () async {
      tab
        ..write(key, 'pestaña')
        ..write(BrowserSessionStorage.sessionIdKey, 's1');
      persistent
        ..write(key, 'de-otra-cuenta')
        ..write(BrowserSessionStorage.sessionIdKey, 's2');

      expect(await storage.readRefreshToken(), 'pestaña');
    });

    test('una pestaña con sesión propia no adopta la persistente', () async {
      tab.write(key, 'pestaña');
      persistent.write(key, 'persistente');

      expect(await storage.readRefreshToken(), 'pestaña');
    });

    test('una pestaña nueva se une a la sesión persistente y a su id',
        () async {
      persistent
        ..write(key, 'persistente')
        ..write(BrowserSessionStorage.sessionIdKey, 's1');

      expect(await storage.readRefreshToken(), 'persistente');
      expect(tab.read(BrowserSessionStorage.sessionIdKey), 's1');
    });

    test('un persistente sin id (guardado antes) recibe uno al adoptarlo',
        () async {
      persistent.write(key, 'persistente');

      expect(await storage.readRefreshToken(), 'persistente');
      final id = persistent.read(BrowserSessionStorage.sessionIdKey);
      expect(id, isNotNull);
      expect(tab.read(BrowserSessionStorage.sessionIdKey), id);
    });

    test('sin sessionStorage usa el persistente', () async {
      persistent.write(key, 'persistente');
      final blocked =
          BrowserSessionStorage(tab: _BlockedStore(), persistent: persistent);

      expect(await blocked.readRefreshToken(), 'persistente');
    });

    test('sin persistente usa el de la pestaña', () async {
      tab.write(key, 'pestaña');

      expect(await storage.readRefreshToken(), 'pestaña');
    });

    test('ignora tokens vacíos en ambos alcances', () async {
      tab.write(key, '');
      persistent.write(key, '');

      expect(await storage.readRefreshToken(), isNull);
    });

    test('en una pestaña nueva usa el persistente', () async {
      persistent.write(key, 'persistente');

      expect(await storage.readRefreshToken(), 'persistente');
    });

    test('ignora un persistente vacío', () async {
      tab.write(key, 'pestaña');
      persistent.write(key, '');

      expect(await storage.readRefreshToken(), 'pestaña');
    });
  });

  group('replaceRefreshToken', () {
    test('no pisa la sesión persistente de otra pestaña', () async {
      await storage.saveRefreshToken('r1');
      persistent
        ..write(key, 'de-otra-cuenta')
        ..write(BrowserSessionStorage.sessionIdKey, 'otra');

      await storage.replaceRefreshToken('r2');

      expect(tab.read(key), 'r2');
      expect(persistent.read(key), 'de-otra-cuenta');
    });

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

  test('clear no borra la sesión persistente de otra pestaña', () async {
    await storage.saveRefreshToken('r1');
    persistent
      ..write(key, 'de-otra-cuenta')
      ..write(BrowserSessionStorage.sessionIdKey, 'otra');

    await storage.clear();

    expect(tab.read(key), isNull);
    expect(persistent.read(key), 'de-otra-cuenta');
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
