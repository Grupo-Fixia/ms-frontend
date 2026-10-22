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

/// Navegador que no guarda cookies (las ignora sin fallar).
class _NoCookies implements KeyValueStore {
  @override
  String? read(String key) => null;

  @override
  void write(String key, String value) {}

  @override
  void remove(String key) {}
}

void main() {
  const key = BrowserSessionStorage.key;
  const idKey = BrowserSessionStorage.sessionIdKey;
  const rememberKey = BrowserSessionStorage.rememberKey;
  const cookieKey = BrowserSessionStorage.browserSessionKey;

  late InMemoryKeyValueStore local;
  late InMemoryKeyValueStore cookies;
  var ids = 0;

  /// Una pestaña: su `sessionStorage` y el `localStorage` y las cookies del
  /// navegador.
  BrowserSessionStorage tabOf(KeyValueStore tab) => BrowserSessionStorage(
        tab: tab,
        shared: local,
        browserSession: cookies,
        newSessionId: () => 's${++ids}',
      );

  late InMemoryKeyValueStore tab;
  late BrowserSessionStorage storage;

  setUp(() {
    ids = 0;
    local = InMemoryKeyValueStore();
    cookies = InMemoryKeyValueStore();
    tab = InMemoryKeyValueStore();
    storage = tabOf(tab);
  });

  /// Cerrar el navegador: se pierden `sessionStorage` y las cookies de sesión.
  void closeBrowser() {
    cookies = InMemoryKeyValueStore();
  }

  test('sin nada guardado no hay token', () async {
    expect(await storage.readRefreshToken(), isNull);
  });

  group('una sola sesión en todo el navegador', () {
    test('una pestaña nueva entra con la sesión ya iniciada', () async {
      await storage.saveRefreshToken('r1');

      final other = tabOf(InMemoryKeyValueStore());

      expect(await other.readRefreshToken(), 'r1');
    });

    test('también con "Mantener sesión iniciada"', () async {
      await storage.saveRefreshToken('r1', persist: true);

      expect(await tabOf(InMemoryKeyValueStore()).readRefreshToken(), 'r1');
    });

    test('la renovación de una pestaña la ven las demás', () async {
      await storage.saveRefreshToken('r1');
      final other = tabOf(InMemoryKeyValueStore());
      await other.readRefreshToken();

      await other.replaceRefreshToken('r2');

      expect(await storage.readRefreshToken(), 'r2');
      expect(tab.read(key), 'r1', reason: 'su copia quedó vieja');
    });

    test('iniciar sesión en otra pestaña reemplaza la sesión de todas',
        () async {
      await storage.saveRefreshToken('cliente');

      await tabOf(InMemoryKeyValueStore()).saveRefreshToken('tecnico');

      expect(await storage.readRefreshToken(), 'tecnico');
    });

    test('una pestaña de una sesión anterior no pisa la nueva', () async {
      await storage.saveRefreshToken('cliente');
      await tabOf(InMemoryKeyValueStore()).saveRefreshToken('tecnico');

      await storage.replaceRefreshToken('cliente-2');
      await storage.clear();

      expect(local.read(key), 'tecnico');
      expect(cookies.read(cookieKey), local.read(idKey));
    });

    test('si otra pestaña cambió la sesión, se descarta la copia vieja',
        () async {
      await storage.saveRefreshToken('cliente');
      await tabOf(InMemoryKeyValueStore()).saveRefreshToken('tecnico');

      await storage.discardStaleTabCopy();

      expect(tab.read(key), isNull);
      expect(local.read(key), 'tecnico', reason: 'no toca la nueva');
    });

    test('si la sesión es la misma, conserva la copia', () async {
      await storage.saveRefreshToken('r1');

      await storage.discardStaleTabCopy();

      expect(tab.read(key), 'r1');
      expect(local.read(key), 'r1');
    });

    test('cerrar sesión en una pestaña la cierra en todas', () async {
      await storage.saveRefreshToken('r1');
      final other = tabOf(InMemoryKeyValueStore());
      await other.readRefreshToken();

      await other.clear();

      expect(local.read(key), isNull);
      expect(local.read(idKey), isNull);
      expect(cookies.read(cookieKey), isNull);
      expect(await tabOf(InMemoryKeyValueStore()).readRefreshToken(), isNull);
    });
  });

  group('cerrar el navegador', () {
    test('sin "Mantener sesión iniciada" la sesión se pierde', () async {
      await storage.saveRefreshToken('r1');

      closeBrowser();

      expect(await tabOf(InMemoryKeyValueStore()).readRefreshToken(), isNull);
      expect(local.read(key), isNull, reason: 'se borra el token viejo');
    });

    test('con "Mantener sesión iniciada" la sesión sigue', () async {
      await storage.saveRefreshToken('r1', persist: true);

      closeBrowser();

      expect(await tabOf(InMemoryKeyValueStore()).readRefreshToken(), 'r1');
    });

    test('la cookie solo guarda el id de la sesión, nunca el token', () async {
      await storage.saveRefreshToken('r1');

      expect(cookies.read(cookieKey), 's1');
      expect(local.read(rememberKey), '0');
    });

    test(
        'un token guardado por la versión anterior se conserva como '
        '"Mantener sesión iniciada"', () async {
      local.write(key, 'antiguo');
      closeBrowser();

      expect(await storage.readRefreshToken(), 'antiguo');
      expect(local.read(idKey), isNotNull);
      expect(local.read(rememberKey), '1');
      expect(tab.read(idKey), local.read(idKey));
    });
  });

  group('respaldo de la pestaña', () {
    test('F5 restaura aunque no haya sesión compartida', () async {
      tab.write(key, 'pestaña');

      expect(await storage.readRefreshToken(), 'pestaña');
    });

    test('si el navegador no guarda cookies, la sesión queda en la pestaña',
        () async {
      final noCookies = BrowserSessionStorage(
        tab: tab,
        shared: local,
        browserSession: _NoCookies(),
      );

      await noCookies.saveRefreshToken('r1');

      expect(local.read(key), isNull);
      expect(await noCookies.readRefreshToken(), 'r1');
    });

    test('si las cookies fallan, la sesión queda en la pestaña', () async {
      final blocked = BrowserSessionStorage(
        tab: tab,
        shared: local,
        browserSession: _BlockedStore(),
      );

      await blocked.saveRefreshToken('r1');

      expect(local.read(key), isNull);
      expect(await blocked.readRefreshToken(), 'r1');
    });

    test('ignora tokens vacíos', () async {
      tab.write(key, '');
      local.write(key, '');

      expect(await storage.readRefreshToken(), isNull);
    });
  });

  test('clear borra la sesión compartida aunque sessionStorage falle',
      () async {
    await storage.saveRefreshToken('r1', persist: true);
    final blockedTab = BrowserSessionStorage(
      tab: _BlockedStore(),
      shared: local,
      browserSession: cookies,
    );

    await expectLater(blockedTab.clear(), throwsStateError);

    expect(local.read(key), isNull);
  });

  test('sin sessionStorage usa la sesión compartida', () async {
    await storage.saveRefreshToken('r1', persist: true);
    final blockedTab = BrowserSessionStorage(
      tab: _BlockedStore(),
      shared: local,
      browserSession: cookies,
    );

    expect(await blockedTab.readRefreshToken(), 'r1');
  });

  test('los errores del navegador llegan al caso de uso', () async {
    final blocked = BrowserSessionStorage(
      tab: _BlockedStore(),
      shared: local,
      browserSession: cookies,
    );

    await expectLater(blocked.readRefreshToken(), throwsStateError);
    await expectLater(blocked.saveRefreshToken('r1'), throwsStateError);
  });

  test(
    'fuera del navegador los almacenes son independientes y en memoria',
    () async {
      final tabStore = tabKeyValueStore()..write(key, 'r1');
      final persistentStore = persistentKeyValueStore();
      final cookieStore = browserSessionKeyValueStore();

      expect(tabStore.read(key), 'r1');
      expect(persistentStore.read(key), isNull);
      expect(cookieStore.read(key), isNull);
      tabStore.remove(key);
      expect(tabStore.read(key), isNull);
      expect(await sharedSessionChanges(idKey).isEmpty, isTrue);
    },
    testOn: '!browser',
  );
}
