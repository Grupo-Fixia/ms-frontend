import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/application/login_user.dart';
import 'package:ms_frontend/features/auth/application/logout_user.dart';
import 'package:ms_frontend/features/auth/application/session_store.dart';
import 'package:ms_frontend/features/auth/domain/auth_exceptions.dart';

import 'fake_auth_repository.dart';

void main() {
  group('LoginUser', () {
    test('autentica, consulta el perfil con el access token y guarda la sesión',
        () async {
      final repository = FakeAuthRepository();
      final store = SessionStore();

      await LoginUser(repository, store, FakeSessionStorage())(
        email: 'ana@fixia.com',
        password: 'Segura123',
      );

      expect(repository.lastEmail, 'ana@fixia.com');
      expect(repository.lastPassword, 'Segura123');
      expect(repository.lastProfileToken, fixtureSession.accessToken);
      expect(store.isAuthenticated, isTrue);
      expect(store.session, fixtureSession);
      expect(store.profile, fixtureProfile);
    });

    test('con "mantener sesión" guarda el refresh token (y solo ese)',
        () async {
      final storage = FakeSessionStorage();

      await LoginUser(FakeAuthRepository(), SessionStore(), storage)(
        email: 'ana@fixia.com',
        password: 'Segura123',
        rememberSession: true,
      );

      expect(storage.refreshToken, fixtureSession.refreshToken);
    });

    test('sin "mantener sesión" descarta cualquier token guardado antes',
        () async {
      final storage = FakeSessionStorage(refreshToken: 'viejo');

      await LoginUser(FakeAuthRepository(), SessionStore(), storage)(
        email: 'ana@fixia.com',
        password: 'Segura123',
      );

      expect(storage.refreshToken, isNull);
    });

    test('si el navegador no deja guardar, el login igual funciona', () async {
      final store = SessionStore();

      await LoginUser(
        FakeAuthRepository(),
        store,
        FakeSessionStorage(failing: true),
      )(email: 'ana@fixia.com', password: 'x', rememberSession: true);

      expect(store.isAuthenticated, isTrue);
    });

    test('un login fallido no guarda nada', () async {
      final storage = FakeSessionStorage();

      await expectLater(
        LoginUser(
          FakeAuthRepository(loginFailure: const AuthFailure('mal')),
          SessionStore(),
          storage,
        )(email: 'ana@fixia.com', password: 'x', rememberSession: true),
        throwsA(isA<AuthFailure>()),
      );

      expect(storage.refreshToken, isNull);
    });

    test('con credenciales inválidas no guarda sesión ni pide el perfil',
        () async {
      final repository = FakeAuthRepository(
        loginFailure: const AuthFailure('Credenciales inválidas'),
      );
      final store = SessionStore();

      await expectLater(
        LoginUser(repository, store, FakeSessionStorage())(email: 'ana@fixia.com', password: 'x'),
        throwsA(isA<AuthFailure>()),
      );

      expect(store.isAuthenticated, isFalse);
      expect(repository.profileCalls, 0);
    });

    test('si el perfil falla cierra la sesión recién abierta y no guarda nada',
        () async {
      final repository = FakeAuthRepository(
        profileFailure: const AuthFailure('Tu sesión expiró.'),
      );
      final store = SessionStore();

      await expectLater(
        LoginUser(repository, store, FakeSessionStorage())(email: 'ana@fixia.com', password: 'x'),
        throwsA(isA<AuthFailure>()),
      );

      expect(store.isAuthenticated, isFalse);
      expect(repository.loggedOutSession, fixtureSession);
    });

    test('si el perfil falla y el cierre también, propaga el error del perfil',
        () async {
      final repository = FakeAuthRepository(
        profileFailure: const AuthFailure('perfil'),
        logoutFailure: const AuthFailure('cierre'),
      );

      await expectLater(
        LoginUser(repository, SessionStore(), FakeSessionStorage())(
          email: 'ana@fixia.com',
          password: 'x',
        ),
        throwsA(
          isA<AuthFailure>().having((f) => f.message, 'message', 'perfil'),
        ),
      );
    });
  });

  group('LogoutUser', () {
    Future<SessionStore> loggedInStore(FakeAuthRepository repository) async {
      final store = SessionStore();
      await LoginUser(repository, store, FakeSessionStorage())(
        email: 'ana@fixia.com',
        password: 'Segura123',
      );
      return store;
    }

    test('cierra la sesión en el backend y la limpia', () async {
      final repository = FakeAuthRepository();
      final store = await loggedInStore(repository);

      await LogoutUser(repository, store, FakeSessionStorage())();

      expect(repository.loggedOutSession, fixtureSession);
      expect(store.isAuthenticated, isFalse);
    });

    test('limpia la sesión local aunque el backend falle', () async {
      final repository = FakeAuthRepository(
        logoutFailure: const AuthFailure('sin conexión'),
      );
      final store = await loggedInStore(FakeAuthRepository());

      await LogoutUser(repository, store, FakeSessionStorage())();

      expect(repository.logoutCalls, 1);
      expect(store.isAuthenticated, isFalse);
    });

    test('borra el refresh token guardado, aunque el backend falle', () async {
      final storage = FakeSessionStorage(refreshToken: 'guardado');
      final store = await loggedInStore(FakeAuthRepository());

      await LogoutUser(
        FakeAuthRepository(logoutFailure: const AuthFailure('sin conexión')),
        store,
        storage,
      )();

      expect(storage.refreshToken, isNull);
    });

    test('si el navegador no deja borrar, igual cierra la sesión', () async {
      final store = await loggedInStore(FakeAuthRepository());

      await LogoutUser(
        FakeAuthRepository(),
        store,
        FakeSessionStorage(failing: true),
      )();

      expect(store.isAuthenticated, isFalse);
    });

    test('sin sesión no llama al backend', () async {
      final repository = FakeAuthRepository();

      await LogoutUser(repository, SessionStore(), FakeSessionStorage())();

      expect(repository.logoutCalls, 0);
    });
  });

  test('SessionStore avisa a los oyentes al iniciar y al limpiar', () {
    final store = SessionStore();
    var notifications = 0;
    store.addListener(() => notifications++);

    store.start(fixtureSession, fixtureProfile);
    store.clear();
    store.clear(); // ya vacía: no vuelve a notificar

    expect(notifications, 2);
  });
}
