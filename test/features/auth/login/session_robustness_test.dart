import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/auth/login/application/login_user.dart';
import 'package:ms_frontend/features/auth/login/application/logout_user.dart';
import 'package:ms_frontend/features/auth/login/application/ports/auth_repository.dart';
import 'package:ms_frontend/features/auth/login/application/refresh_session.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_session.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_session_storage.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/http_auth_repository.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/key_value_store.dart';
import 'package:ms_frontend/features/auth/login/presentation/login_controller.dart';

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

const _networkDown = AuthFailure('Sin conexión');
const _unauthorized = AuthFailure('Sesión inválida', isUnauthorized: true);

/// Backend con tokens de un solo uso y fallas configurables.
class _Backend implements AuthRepository {
  final Map<String, UserProfile> _refresh = {};
  final Map<String, UserProfile> _access = {};
  final List<String> revoked = [];
  var _n = 0;

  /// Si no es `null`, `refresh` espera a que se complete.
  Completer<void>? holdRefresh;
  Object? refreshError;
  Object? profileError;

  AuthSession issue(UserProfile user) {
    _n++;
    final s = AuthSession(
      accessToken: 'a$_n',
      refreshToken: 'r$_n',
      expiresIn: const Duration(minutes: 15),
    );
    _refresh[s.refreshToken] = user;
    _access[s.accessToken] = user;
    return s;
  }

  bool isValid(String? token) => token != null && _refresh.containsKey(token);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async =>
      issue(email == _beto.email ? _beto : _ana);

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    await holdRefresh?.future;
    final error = refreshError;
    if (error != null) throw error;
    final user = _refresh.remove(refreshToken);
    if (user == null) throw _unauthorized;
    return issue(user);
  }

  @override
  Future<UserProfile> fetchProfile(String accessToken) async {
    final error = profileError;
    if (error != null) throw error;
    final user = _access[accessToken];
    if (user == null) throw _unauthorized;
    return user;
  }

  @override
  Future<void> logout(AuthSession session) async {
    if (_refresh.remove(session.refreshToken) != null) {
      revoked.add(session.refreshToken);
    }
  }
}

void main() {
  late _Backend backend;
  late SessionStore store;
  late InMemoryKeyValueStore tab;
  late InMemoryKeyValueStore local;
  late BrowserSessionStorage storage;

  setUp(() {
    backend = _Backend();
    store = SessionStore();
    tab = InMemoryKeyValueStore();
    local = InMemoryKeyValueStore();
    storage = BrowserSessionStorage(tab: tab, persistent: local);
  });

  Future<void> login({bool remember = true}) => LoginUser(
        backend,
        store,
        storage,
      )(email: _ana.email, password: 'x', rememberSession: remember);

  RefreshSession refresh() => RefreshSession(backend, store, storage);
  LogoutUser logout() => LogoutUser(backend, store, storage);

  group('cerrar sesión mientras se renueva', () {
    test('la renovación que termina después no revive la sesión', () async {
      await login();
      backend.holdRefresh = Completer<void>();
      final renewal = refresh().renew();

      // Se cierra sesión sin esperar (como si la renovación siguiera).
      store.clear();
      await storage.clear();
      backend.holdRefresh!.complete();

      expect(await renewal, isFalse);
      expect(store.isAuthenticated, isFalse);
      expect(local.read(BrowserSessionStorage.key), isNull);
      expect(tab.read(BrowserSessionStorage.key), isNull);
    });

    test('LogoutUser espera la renovación y revoca el token nuevo', () async {
      await login();
      backend.holdRefresh = Completer<void>();
      final renewal = refresh().renew();
      final logoutDone = logout()();

      backend.holdRefresh!.complete();
      await Future.wait([renewal, logoutDone]);

      expect(store.isAuthenticated, isFalse);
      expect(backend.revoked, ['r2'],
          reason: 'el token que dejó la renovación');
      expect(backend.isValid('r2'), isFalse);
      expect(local.read(BrowserSessionStorage.key), isNull);
    });

    test('si mientras tanto se inició otra sesión, se respeta la nueva',
        () async {
      await login();
      backend.holdRefresh = Completer<void>();
      final renewal = refresh().renew();
      final other = backend.issue(_beto);
      store.start(other, _beto);
      backend.holdRefresh!.complete();

      expect(await renewal, isTrue);
      expect(store.session, same(other));
      expect(store.profile, _beto);
    });
  });

  group('sin red al renovar no se pierde la sesión', () {
    test('renew lanza BackendUnreachableException; call devuelve false',
        () async {
      await login();
      final session = store.session;
      backend.refreshError = _networkDown;

      await expectLater(
        refresh().renew(),
        throwsA(isA<BackendUnreachableException>()),
      );
      expect(await refresh()(), isFalse);
      expect(store.session, same(session), reason: 'la sesión sigue intacta');
      expect(backend.isValid(local.read(BrowserSessionStorage.key)), isTrue);
    });

    test('AuthorizedHttp informa sin red, no sesión vencida', () async {
      await login();
      backend.refreshError = _networkDown;
      final authorized = AuthorizedHttp(
        accessToken: () => 'vencido',
        renewSession: refresh().renew,
      );

      await expectLater(
        authorized.send((_) async => http.Response('', 401)),
        throwsA(isA<BackendUnreachableException>()),
      );
    });

    test('un error inesperado al renovar sí cuenta como sesión vencida',
        () async {
      final authorized = AuthorizedHttp(
        accessToken: () => 'vencido',
        renewSession: () => throw StateError('falla'),
      );

      await expectLater(
        authorized.send((_) async => http.Response('', 401)),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });

  group('renovar con el token guardado por otra pestaña', () {
    Future<void> otherTabConsumesToken() async {
      // Otra pestaña restaura con el token compartido y guarda el nuevo.
      final stored = local.read(BrowserSessionStorage.key)!;
      final renewed = await backend.refresh(stored);
      local.write(BrowserSessionStorage.key, renewed.refreshToken);
    }

    test('sin red al usar el guardado: no saca al usuario', () async {
      await login();
      await otherTabConsumesToken();
      final original = store.session!.refreshToken;
      // El token propio falla (401) y el guardado no llega por red.
      final down = _BackendSwitch(backend, failStored: _networkDown);

      await expectLater(
        RefreshSession(down, store, storage).renew(),
        throwsA(isA<BackendUnreachableException>()),
      );
      expect(store.session!.refreshToken, original);
    });

    test('si el guardado es de otra cuenta, deja su reemplazo en el navegador',
        () async {
      await login(remember: false);
      // En otra pestaña Beto inicia sesión con "Mantener sesión".
      final beto = await backend.login(email: _beto.email, password: 'x');
      local.write(BrowserSessionStorage.key, beto.refreshToken);
      // El token de Ana se gastó (por ejemplo, en otra llamada).
      await backend.refresh(store.session!.refreshToken);

      expect(await refresh()(), isFalse);
      expect(store.profile, _ana, reason: 'no se mezcla con Beto');
      final saved = local.read(BrowserSessionStorage.key);
      expect(saved, isNot(beto.refreshToken));
      expect(backend.isValid(saved), isTrue,
          reason: 'Beto conserva "Mantener sesión"');
    });

    test('sin red al consultar el perfil: guarda el token y avisa sin red',
        () async {
      await login();
      await otherTabConsumesToken();
      backend.profileError = _networkDown;

      await expectLater(
        refresh().renew(),
        throwsA(isA<BackendUnreachableException>()),
      );
      expect(backend.isValid(local.read(BrowserSessionStorage.key)), isTrue);
    });

    test('si el guardado también es inválido, la sesión venció', () async {
      await login();
      await backend.refresh(store.session!.refreshToken);
      local.write(BrowserSessionStorage.key, 'invalido');

      expect(await refresh().renew(), isFalse);
    });

    test('si el perfil del guardado da 401, la sesión venció', () async {
      await login();
      await otherTabConsumesToken();
      backend.profileError = _unauthorized;

      expect(await refresh().renew(), isFalse);
    });
  });

  group('login', () {
    test('si el perfil falla con un error inesperado, cierra la sesión abierta',
        () async {
      backend.profileError = StateError('respuesta rara');

      await expectLater(login(), throwsStateError);
      expect(store.isAuthenticated, isFalse);
      expect(backend.revoked, hasLength(1));
    });

    test('el controlador muestra un mensaje y no queda colgado', () async {
      backend.profileError = StateError('respuesta rara');
      final controller = LoginController(
        loginUser: LoginUser(backend, store, storage),
      );

      final ok = await controller.login(email: _ana.email, password: 'x');

      expect(ok, isFalse);
      expect(controller.isSubmitting, isFalse);
      expect(controller.errorMessage, LoginController.unexpectedErrorMessage);
    });

    test('un rol que no es texto en /me no rompe el login', () async {
      final repository = HttpAuthRepository(
        client: MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'id': 'usr-1',
                'email': 'ana@fixia.com',
                'firstName': 'Ana',
                'lastName': 'Pérez',
                'role': 7,
              })),
              200,
            )),
        baseUrl: Uri.parse('http://localhost'),
      );

      final profile = await repository.fetchProfile('a1');

      expect(profile.id, 'usr-1');
      expect(profile.role, isNull);
    });
  });
}

/// Hace que solo la renovación con el token guardado (no el de la sesión)
/// falle con [failStored].
class _BackendSwitch implements AuthRepository {
  _BackendSwitch(this._inner, {required this.failStored});

  final _Backend _inner;
  final AuthFailure failStored;
  var _calls = 0;

  @override
  Future<AuthSession> refresh(String refreshToken) {
    _calls++;
    if (_calls > 1) throw failStored;
    return _inner.refresh(refreshToken);
  }

  @override
  Future<UserProfile> fetchProfile(String accessToken) =>
      _inner.fetchProfile(accessToken);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) =>
      _inner.login(email: email, password: password);

  @override
  Future<void> logout(AuthSession session) => _inner.logout(session);
}
