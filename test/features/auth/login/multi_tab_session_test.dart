import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/login_user.dart';
import 'package:ms_frontend/features/auth/login/application/ports/auth_repository.dart';
import 'package:ms_frontend/features/auth/login/application/ports/session_storage.dart';
import 'package:ms_frontend/features/auth/login/application/refresh_session.dart';
import 'package:ms_frontend/features/auth/login/application/restore_session.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_session.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_session_storage.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/key_value_store.dart';

const _ana = UserProfile(
  id: 'usr-ana',
  email: 'ana@fixia.com',
  firstName: 'Ana',
  lastName: 'Pérez',
  role: UserRole.client,
);

const _beto = UserProfile(
  id: 'usr-beto',
  email: 'beto@fixia.com',
  firstName: 'Beto',
  lastName: 'Gómez',
  role: UserRole.professional,
);

/// Backend como ms-users: cada refresh token sirve una sola vez y un token
/// ya usado responde 401 (sin revocar los demás).
class _Backend implements AuthRepository {
  _Backend({this.refreshDelay});

  final Duration? refreshDelay;
  final Map<String, UserProfile> _refreshTokens = {};
  final Map<String, UserProfile> _accessTokens = {};
  var _counter = 0;
  int refreshCalls = 0;

  AuthSession _issue(UserProfile user) {
    _counter++;
    final session = AuthSession(
      accessToken: 'a$_counter',
      refreshToken: 'r$_counter',
      expiresIn: const Duration(minutes: 15),
    );
    _refreshTokens[session.refreshToken] = user;
    _accessTokens[session.accessToken] = user;
    return session;
  }

  bool isValid(String? refreshToken) =>
      refreshToken != null && _refreshTokens.containsKey(refreshToken);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async =>
      _issue(email == _beto.email ? _beto : _ana);

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshDelay != null) await Future<void>.delayed(refreshDelay!);
    final user = _refreshTokens.remove(refreshToken);
    if (user == null) {
      throw const AuthFailure('Sesión inválida', isUnauthorized: true);
    }
    return _issue(user);
  }

  @override
  Future<UserProfile> fetchProfile(String accessToken) async {
    final user = _accessTokens[accessToken];
    if (user == null) {
      throw const AuthFailure('Sesión inválida', isUnauthorized: true);
    }
    return user;
  }

  @override
  Future<void> logout(AuthSession session) async {}
}

/// Una pestaña del navegador: su propio `sessionStorage` y el `localStorage`
/// compartido.
class _Tab {
  _Tab(this.backend, KeyValueStore sharedLocal)
      : tabStore = InMemoryKeyValueStore(),
        store = SessionStore() {
    storage = BrowserSessionStorage(tab: tabStore, persistent: sharedLocal);
  }

  final _Backend backend;
  final InMemoryKeyValueStore tabStore;
  final SessionStore store;
  late final BrowserSessionStorage storage;

  Future<void> login({bool remember = true, String email = 'ana@fixia.com'}) =>
      LoginUser(backend, store, storage)(
        email: email,
        password: 'x',
        rememberSession: remember,
      );

  /// Recargar (F5): la memoria se pierde y se restaura desde el navegador.
  Future<bool> reload() {
    store.clear();
    return RestoreSession(backend, store, storage)();
  }

  Future<bool> renew() => RefreshSession(backend, store, storage)();

  String? get tabToken => tabStore.read(BrowserSessionStorage.key);
}

/// Simula una carrera: la primera lectura devuelve un token viejo y las
/// siguientes, lo que haya realmente guardado.
class _StaleFirstRead implements SessionStorage {
  _StaleFirstRead(this._inner, this._stale);

  final SessionStorage _inner;
  String? _stale;

  @override
  Future<String?> readRefreshToken() async {
    final stale = _stale;
    _stale = null;
    if (stale != null) return stale;
    return _inner.readRefreshToken();
  }

  @override
  Future<void> saveRefreshToken(String token, {bool persist = false}) =>
      _inner.saveRefreshToken(token, persist: persist);

  @override
  Future<void> replaceRefreshToken(String token) =>
      _inner.replaceRefreshToken(token);

  @override
  Future<void> clear() => _inner.clear();
}

void main() {
  late _Backend backend;
  late InMemoryKeyValueStore local;

  setUp(() {
    backend = _Backend();
    local = InMemoryKeyValueStore();
  });

  String? persisted() => local.read(BrowserSessionStorage.key);

  group('"Mantener sesión" con dos pestañas (hallazgo de QA en #34)', () {
    test('la pestaña con la copia vieja recarga sin perder la sesión',
        () async {
      final a = _Tab(backend, local);
      final b = _Tab(backend, local);
      await a.login();

      // B se abre y restaura: rota el token compartido.
      expect(await b.reload(), isTrue);
      expect(a.tabToken, isNot(persisted()), reason: 'A quedó con copia vieja');

      // A recarga: usa el persistente (el más nuevo), no su copia vieja.
      expect(await a.reload(), isTrue);
      expect(a.store.profile, _ana);
      expect(backend.isValid(persisted()), isTrue);

      // Y B puede volver a recargar: "Mantener sesión" sigue viva.
      expect(await b.reload(), isTrue);
      expect(backend.isValid(persisted()), isTrue);
    });

    test(
        'si leyó un token que otra pestaña ya renovó, reintenta con el nuevo '
        'y no borra el guardado', () async {
      final a = _Tab(backend, local);
      await a.login();
      final old = persisted()!;
      await _Tab(backend, local).reload(); // B rota el token.
      final fresh = persisted()!;

      final restore = RestoreSession(
        backend,
        a.store..clear(),
        _StaleFirstRead(a.storage, old),
      );

      expect(await restore(), isTrue);
      expect(persisted(), isNot(fresh), reason: 'se rotó otra vez');
      expect(backend.isValid(persisted()), isTrue);
    });

    test('un token vencido sí se borra cuando nadie lo reemplazó', () async {
      local.write(BrowserSessionStorage.key, 'vencido');
      final a = _Tab(backend, local);

      expect(await a.reload(), isFalse);
      expect(persisted(), isNull);
    });

    test(
        'si el reintento con el nuevo también falla y es el guardado, se borra',
        () async {
      local.write(BrowserSessionStorage.key, 'nuevo-pero-invalido');
      final a = _Tab(backend, local);
      final restore = RestoreSession(
        backend,
        a.store,
        _StaleFirstRead(a.storage, 'viejo'),
      );

      expect(await restore(), isFalse);
      expect(persisted(), isNull);
    });

    test('sin "Mantener sesión", F5 restaura desde la pestaña', () async {
      final a = _Tab(backend, local);
      await a.login(remember: false);

      expect(persisted(), isNull);
      expect(await a.reload(), isTrue);
      expect(backend.isValid(a.tabToken), isTrue);
    });
  });

  group('dos cuentas en el mismo navegador', () {
    test(
        'la pestaña sin "Mantener" no se vuelve la cuenta recordada al '
        'recargar', () async {
      final tecnico = _Tab(backend, local);
      await tecnico.login(email: 'beto@fixia.com', remember: false);
      final cliente = _Tab(backend, local);
      await cliente.login();

      expect(await tecnico.reload(), isTrue);
      expect(tecnico.store.profile, _beto);
      expect(await cliente.reload(), isTrue);
      expect(cliente.store.profile, _ana);
    });

    test('renovar en la pestaña sin "Mantener" no pisa la cuenta recordada',
        () async {
      final tecnico = _Tab(backend, local);
      await tecnico.login(email: 'beto@fixia.com', remember: false);
      final cliente = _Tab(backend, local);
      await cliente.login();
      final remembered = persisted();

      expect(await tecnico.renew(), isTrue);
      expect(persisted(), remembered);

      // Una pestaña nueva abre la cuenta recordada, no la del técnico.
      final nueva = _Tab(backend, local);
      expect(await nueva.reload(), isTrue);
      expect(nueva.store.profile, _ana);
      expect(await cliente.reload(), isTrue);
      expect(cliente.store.profile, _ana);
    });

    test('dos cuentas con "Mantener": cada pestaña conserva la suya', () async {
      final cliente = _Tab(backend, local);
      await cliente.login();
      final tecnico = _Tab(backend, local);
      await tecnico.login(email: 'beto@fixia.com');

      expect(await cliente.renew(), isTrue);
      expect(await cliente.reload(), isTrue);
      expect(cliente.store.profile, _ana);
      expect(await tecnico.reload(), isTrue);
      expect(tecnico.store.profile, _beto);
      // La recordada para pestañas nuevas es la del último inicio de sesión.
      final nueva = _Tab(backend, local);
      expect(await nueva.reload(), isTrue);
      expect(nueva.store.profile, _beto);
    });

    test('cerrar sesión en una pestaña no cierra la otra cuenta', () async {
      final tecnico = _Tab(backend, local);
      await tecnico.login(email: 'beto@fixia.com', remember: false);
      final cliente = _Tab(backend, local);
      await cliente.login();

      await tecnico.storage.clear();
      tecnico.store.clear();

      expect(persisted(), isNotNull);
      expect(await cliente.reload(), isTrue);
      expect(cliente.store.profile, _ana);
    });

    test(
        'en una pestaña que abrió la cuenta recordada: cerrar sesión y entrar '
        'con otra cuenta deja esa pestaña con la nueva', () async {
      final cliente = _Tab(backend, local);
      await cliente.login();
      final otra = _Tab(backend, local);
      expect(await otra.reload(), isTrue, reason: 'se une a la recordada');
      expect(otra.store.profile, _ana);

      // Cerrar sesión cierra la sesión recordada que comparten.
      await otra.storage.clear();
      otra.store.clear();
      expect(persisted(), isNull);

      await otra.login(email: 'beto@fixia.com', remember: false);
      expect(await otra.reload(), isTrue);
      expect(otra.store.profile, _beto);
      expect(await _Tab(backend, local).reload(), isFalse,
          reason: 'una pestaña nueva no abre ninguna de las dos');
    });
  });

  group('renovar a mitad de sesión', () {
    test('si otra pestaña ya usó su token, renueva con el guardado', () async {
      final a = _Tab(backend, local);
      await a.login();
      await _Tab(backend, local).reload(); // B rota el token compartido.

      expect(await a.renew(), isTrue);
      expect(a.store.profile, _ana);
      expect(a.store.session!.refreshToken, persisted());
      expect(backend.isValid(persisted()), isTrue);
    });

    test('no adopta la sesión de otra cuenta guardada en el navegador',
        () async {
      final a = _Tab(backend, local);
      await a.login(remember: false);
      final b = _Tab(backend, local);
      await b.login(email: 'beto@fixia.com');
      // A pierde su token (lo usó otra llamada, por ejemplo).
      await backend.refresh(a.store.session!.refreshToken);

      expect(await a.renew(), isFalse);
      expect(a.store.profile, _ana, reason: 'no se mezcla con Beto');
    });

    test('si el guardado es el mismo que falló, no reintenta', () async {
      final a = _Tab(backend, local);
      await a.login();
      await backend.refresh(a.store.session!.refreshToken);
      final calls = backend.refreshCalls;

      expect(await a.renew(), isFalse);
      expect(backend.refreshCalls, calls + 1);
    });
  });

  test('cinco llamadas que renuevan a la vez hacen una sola renovación',
      () async {
    backend = _Backend(refreshDelay: const Duration(milliseconds: 20));
    final a = _Tab(backend, InMemoryKeyValueStore());
    await a.login();
    final calls = backend.refreshCalls;

    final results = await Future.wait(List.generate(5, (_) => a.renew()));

    expect(results, everyElement(isTrue));
    expect(backend.refreshCalls, calls + 1);
    expect(backend.isValid(a.store.session!.refreshToken), isTrue);

    // Terminada la renovación, la siguiente vuelve a renovar.
    expect(await a.renew(), isTrue);
    expect(backend.refreshCalls, calls + 2);
  });
}
