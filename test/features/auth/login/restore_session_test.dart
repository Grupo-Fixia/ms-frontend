import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/restore_session.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';

import 'fake_auth_repository.dart';

void main() {
  test('sin token guardado no llama al backend ni inicia sesión', () async {
    final repository = FakeAuthRepository();
    final store = SessionStore();

    final restored =
        await RestoreSession(repository, store, FakeSessionStorage())();

    expect(restored, isFalse);
    expect(repository.refreshCalls, 0);
    expect(store.isAuthenticated, isFalse);
  });

  test('canjea el token guardado, guarda el nuevo y restaura la sesión',
      () async {
    final repository = FakeAuthRepository();
    final storage = FakeSessionStorage(refreshToken: 'guardado');
    final store = SessionStore();

    final restored = await RestoreSession(repository, store, storage)();

    expect(restored, isTrue);
    expect(repository.lastRefreshToken, 'guardado');
    // El refresh token es de un solo uso: el guardado debe ser el que rotó.
    expect(storage.refreshToken, fixtureRefreshedSession.refreshToken);
    expect(repository.lastProfileToken, fixtureRefreshedSession.accessToken);
    expect(store.isAuthenticated, isTrue);
    expect(store.session, fixtureRefreshedSession);
    expect(store.profile, fixtureProfile);
  });

  test('con 401 borra el token guardado y no inicia sesión', () async {
    final repository = FakeAuthRepository(
      refreshFailure: const AuthFailure('vencido', isUnauthorized: true),
    );
    final storage = FakeSessionStorage(refreshToken: 'vencido');
    final store = SessionStore();

    final restored = await RestoreSession(repository, store, storage)();

    expect(restored, isFalse);
    expect(storage.refreshToken, isNull);
    expect(store.isAuthenticated, isFalse);
  });

  test('si falla la red conserva el token para reintentar después', () async {
    final repository = FakeAuthRepository(
      refreshFailure: const AuthFailure('sin conexión'),
    );
    final storage = FakeSessionStorage(refreshToken: 'guardado');
    final store = SessionStore();

    final restored = await RestoreSession(repository, store, storage)();

    expect(restored, isFalse);
    expect(storage.refreshToken, 'guardado');
    expect(store.isAuthenticated, isFalse);
  });

  test('si el perfil da 401 tras el canje, limpia el almacenamiento',
      () async {
    final repository = FakeAuthRepository(
      profileFailure: const AuthFailure('expiró', isUnauthorized: true),
    );
    final storage = FakeSessionStorage(refreshToken: 'guardado');
    final store = SessionStore();

    final restored = await RestoreSession(repository, store, storage)();

    expect(restored, isFalse);
    expect(storage.refreshToken, isNull);
    expect(store.isAuthenticated, isFalse);
  });

  test('si el perfil falla por red tras el canje, conserva el token nuevo',
      () async {
    final repository = FakeAuthRepository(
      profileFailure: const AuthFailure('sin conexión'),
    );
    final storage = FakeSessionStorage(refreshToken: 'guardado');

    final restored =
        await RestoreSession(repository, SessionStore(), storage)();

    expect(restored, isFalse);
    expect(storage.refreshToken, fixtureRefreshedSession.refreshToken);
  });

  test('si el navegador no deja leer el almacenamiento no lanza', () async {
    final repository = FakeAuthRepository();

    final restored = await RestoreSession(
      repository,
      SessionStore(),
      FakeSessionStorage(failing: true),
    )();

    expect(restored, isFalse);
    expect(repository.refreshCalls, 0);
  });
}
