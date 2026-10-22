import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/follow_shared_session.dart';
import 'package:ms_frontend/features/auth/login/application/login_user.dart';
import 'package:ms_frontend/features/auth/login/application/logout_user.dart';
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
  _Tab(this.backend, KeyValueStore sharedLocal, KeyValueStore cookies)
      : tabStore = InMemoryKeyValueStore(),
        store = SessionStore() {
    storage = BrowserSessionStorage(
      tab: tabStore,
      shared: sharedLocal,
      browserSession: cookies,
    );
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

  @override
  Future<void> discardStaleTabCopy() => _inner.discardStaleTabCopy();
}

void main() {
  late _Backend backend;
  late InMemoryKeyValueStore local;
  late InMemoryKeyValueStore cookies;

  setUp(() {
    backend = _Backend();
    local = InMemoryKeyValueStore();
    cookies = InMemoryKeyValueStore();
  });

  String? persisted() => local.read(BrowserSessionStorage.key);

  group('"Mantener sesión" con dos pestañas (hallazgo de QA en #34)', () {
    test('la pestaña con la copia vieja recarga sin perder la sesión',
        () async {
      final a = _Tab(backend, local, cookies);
      final b = _Tab(backend, local, cookies);
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
      final a = _Tab(backend, local, cookies);
      await a.login();
      final old = persisted()!;
      await _Tab(backend, local, cookies).reload(); // B rota el token.
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
      final a = _Tab(backend, local, cookies);

      expect(await a.reload(), isFalse);
      expect(persisted(), isNull);
    });

    test(
        'si el reintento con el nuevo también falla y es el guardado, se borra',
        () async {
      local.write(BrowserSessionStorage.key, 'nuevo-pero-invalido');
      final a = _Tab(backend, local, cookies);
      final restore = RestoreSession(
        backend,
        a.store,
        _StaleFirstRead(a.storage, 'viejo'),
      );

      expect(await restore(), isFalse);
      expect(persisted(), isNull);
    });

    test('sin "Mantener sesión", F5 restaura la sesión', () async {
      final a = _Tab(backend, local, cookies);
      await a.login(remember: false);

      expect(await a.reload(), isTrue);
      expect(a.store.profile, _ana);
      expect(backend.isValid(persisted()), isTrue);
    });
  });

  group('una sola sesión en todo el navegador (pedido de QA)', () {
    for (final remember in [false, true]) {
      final label = remember ? 'con' : 'sin';
      test('$label "Mantener": una pestaña nueva entra con la sesión iniciada',
          () async {
        final a = _Tab(backend, local, cookies);
        await a.login(remember: remember);

        final b = _Tab(backend, local, cookies);
        expect(await b.reload(), isTrue);
        expect(b.store.profile, _ana);

        // Las dos siguen funcionando: comparten el token más nuevo.
        expect(await a.renew(), isTrue);
        expect(await b.renew(), isTrue);
        expect(await a.reload(), isTrue);
        expect(await b.reload(), isTrue);
        expect(backend.isValid(persisted()), isTrue);
      });
    }

    test('sin "Mantener": cerrar el navegador cierra la sesión', () async {
      final a = _Tab(backend, local, cookies);
      await a.login(remember: false);

      cookies = InMemoryKeyValueStore(); // El navegador borra sus cookies.
      final reopened = _Tab(backend, local, cookies);

      expect(await reopened.reload(), isFalse);
      expect(persisted(), isNull);
    });

    test('con "Mantener": cerrar el navegador conserva la sesión', () async {
      final a = _Tab(backend, local, cookies);
      await a.login();

      cookies = InMemoryKeyValueStore();
      final reopened = _Tab(backend, local, cookies);

      expect(await reopened.reload(), isTrue);
      expect(reopened.store.profile, _ana);
    });

    test('cerrar sesión en una pestaña: la otra la sigue y queda sin sesión',
        () async {
      final a = _Tab(backend, local, cookies);
      await a.login();
      final b = _Tab(backend, local, cookies);
      await b.reload();

      await LogoutUser(backend, b.store, b.storage)();
      final change = await FollowSharedSession(backend, a.store, a.storage)();

      expect(change, SharedSessionChange.signedOut);
      expect(a.store.isAuthenticated, isFalse);
      expect(a.tabToken, isNull);
      expect(await a.reload(), isFalse, reason: 'F5 no la revive');
      expect(await _Tab(backend, local, cookies).reload(), isFalse);
    });

    test('entrar con otra cuenta en una pestaña: la otra pasa a esa cuenta',
        () async {
      final a = _Tab(backend, local, cookies);
      await a.login();
      final b = _Tab(backend, local, cookies);
      await b.reload();
      await LogoutUser(backend, b.store, b.storage)();
      await b.login(email: 'beto@fixia.com', remember: false);

      final change = await FollowSharedSession(backend, a.store, a.storage)();

      expect(change, SharedSessionChange.otherAccount);
      expect(a.store.profile, _beto);
      expect(await a.reload(), isTrue);
      expect(a.store.profile, _beto);
      expect(await b.renew(), isTrue);
      expect(b.store.profile, _beto);
    });

    test('un aviso sin cambio de cuenta deja la misma cuenta', () async {
      final a = _Tab(backend, local, cookies);
      await a.login();

      final change = await FollowSharedSession(backend, a.store, a.storage)();

      expect(change, SharedSessionChange.sameAccount);
      expect(a.store.profile, _ana);
      expect(backend.isValid(persisted()), isTrue);
    });

    test('varios avisos seguidos se atienden uno detrás de otro', () async {
      final a = _Tab(backend, local, cookies);
      await a.login();
      final follow = FollowSharedSession(backend, a.store, a.storage);

      final results = await Future.wait([follow(), follow(), follow()]);

      expect(results, everyElement(SharedSessionChange.sameAccount));
      expect(a.store.profile, _ana);
      expect(backend.isValid(persisted()), isTrue);
    });
  });

  group('renovar a mitad de sesión', () {
    test('si otra pestaña ya usó su token, renueva con el guardado', () async {
      final a = _Tab(backend, local, cookies);
      await a.login();
      await _Tab(backend, local, cookies)
          .reload(); // B rota el token compartido.

      expect(await a.renew(), isTrue);
      expect(a.store.profile, _ana);
      expect(a.store.session!.refreshToken, persisted());
      expect(backend.isValid(persisted()), isTrue);
    });

    test('no adopta la sesión de otra cuenta guardada en el navegador',
        () async {
      final a = _Tab(backend, local, cookies);
      await a.login(remember: false);
      final b = _Tab(backend, local, cookies);
      await b.login(email: 'beto@fixia.com');
      // A pierde su token (lo usó otra llamada, por ejemplo).
      await backend.refresh(a.store.session!.refreshToken);

      expect(await a.renew(), isFalse);
      expect(a.store.profile, _ana, reason: 'no se mezcla con Beto');
    });

    test('si el guardado es el mismo que falló, no reintenta', () async {
      final a = _Tab(backend, local, cookies);
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
    final a = _Tab(backend, InMemoryKeyValueStore(), InMemoryKeyValueStore());
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
