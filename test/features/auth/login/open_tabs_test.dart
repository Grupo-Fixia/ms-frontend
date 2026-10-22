import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_session_storage.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/key_value_store.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/open_tabs.dart';

/// Sin "Mantener sesión iniciada" la sesión dura hasta que se cierra la
/// última pestaña de Fixia (pedido de QA, GC-394).
void main() {
  late InMemoryKeyValueStore local;
  late InMemoryKeyValueStore cookies;
  late DateTime now;
  var tabs = 0;

  setUp(() {
    local = InMemoryKeyValueStore();
    cookies = InMemoryKeyValueStore();
    now = DateTime(2026, 10, 22, 14);
    tabs = 0;
  });

  OpenTabs openTabs() => OpenTabs(local, now: () => now, tabId: 't${++tabs}');

  /// Una pestaña del navegador: su `sessionStorage`, su señal de vida y el
  /// `localStorage` y las cookies compartidos.
  ({BrowserSessionStorage storage, OpenTabs presence, KeyValueStore tab})
      openTab() {
    final presence = openTabs();
    final tab = InMemoryKeyValueStore();
    return (
      storage: BrowserSessionStorage(
        tab: tab,
        shared: local,
        browserSession: cookies,
        openTabs: presence,
      ),
      presence: presence,
      tab: tab,
    );
  }

  group('OpenTabs', () {
    test('sin otras pestañas no hay ninguna viva', () {
      final a = openTabs()..markAlive();

      expect(a.anyOtherAlive(), isFalse, reason: 'no se cuenta a sí misma');
    });

    test('ve las demás pestañas abiertas', () {
      final a = openTabs()..markAlive();
      final b = openTabs();

      expect(b.anyOtherAlive(), isTrue);
      a.markClosed();
      expect(b.anyOtherAlive(), isFalse);
    });

    test('una pestaña que dejó de avisar deja de contar y se limpia', () {
      openTabs().markAlive();
      final b = openTabs();

      now = now.add(OpenTabs.timeout);
      expect(b.anyOtherAlive(), isTrue, reason: 'justo en el límite');
      now = now.add(const Duration(seconds: 1));
      expect(b.anyOtherAlive(), isFalse);
      expect(local.keysStartingWith(OpenTabs.prefix), isEmpty);
    });

    test('una señal dañada no cuenta', () {
      local.write('${OpenTabs.prefix}rota', 'no-es-fecha');

      expect(openTabs().anyOtherAlive(), isFalse);
    });

    test('el aviso periódico es más frecuente que el vencimiento', () {
      expect(OpenTabs.heartbeat * 4, lessThan(OpenTabs.timeout));
    });
  });

  group('sin "Mantener sesión iniciada"', () {
    test('una pestaña nueva entra mientras otra siga abierta', () async {
      final a = openTab();
      await a.storage.saveRefreshToken('r1');
      a.presence.markAlive();

      expect(await openTab().storage.readRefreshToken(), 'r1');
    });

    test('al cerrar la última pestaña la sesión termina', () async {
      final a = openTab();
      await a.storage.saveRefreshToken('r1');
      a.presence.markAlive();

      a.presence.markClosed(); // Se cierra la única pestaña.

      expect(await openTab().storage.readRefreshToken(), isNull);
      expect(local.read(BrowserSessionStorage.key), isNull,
          reason: 'no queda el token guardado');
    });

    test('si quedan otras pestañas, cerrar una no termina la sesión', () async {
      final a = openTab();
      await a.storage.saveRefreshToken('r1');
      a.presence.markAlive();
      final b = openTab();
      await b.storage.readRefreshToken();
      b.presence.markAlive();

      a.presence.markClosed();

      expect(await openTab().storage.readRefreshToken(), 'r1');
    });

    test('recargar (F5) la única pestaña no termina la sesión', () async {
      final a = openTab();
      await a.storage.saveRefreshToken('r1');
      a.presence
        ..markAlive()
        ..markClosed(); // Al recargar, la pestaña deja de contar un momento.

      expect(await a.storage.readRefreshToken(), 'r1');
    });

    test('si el navegador se cuelga, la sesión termina al vencer la señal',
        () async {
      final a = openTab();
      await a.storage.saveRefreshToken('r1');
      a.presence.markAlive();

      now = now.add(OpenTabs.timeout + const Duration(seconds: 1));

      expect(await openTab().storage.readRefreshToken(), isNull);
    });
  });

  test('con "Mantener sesión iniciada" la sesión sigue sin pestañas abiertas',
      () async {
    final a = openTab();
    await a.storage.saveRefreshToken('r1', persist: true);
    a.presence
      ..markAlive()
      ..markClosed();

    expect(await openTab().storage.readRefreshToken(), 'r1');
  });
}
