import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/refresh_session.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';

import 'fake_auth_repository.dart';

void main() {
  test('sin sesión no intenta renovar', () async {
    final repository = FakeAuthRepository();

    final renewed = await RefreshSession(
      repository,
      SessionStore(),
      FakeSessionStorage(),
    )();

    expect(renewed, isFalse);
    expect(repository.refreshCalls, 0);
  });

  test('renueva con el refresh token y reemplaza la sesión', () async {
    final repository = FakeAuthRepository();
    final store = SessionStore()..start(fixtureSession, fixtureProfile);

    final renewed =
        await RefreshSession(repository, store, FakeSessionStorage())();

    expect(renewed, isTrue);
    expect(repository.lastRefreshToken, fixtureSession.refreshToken);
    expect(store.session, same(fixtureRefreshedSession));
    expect(store.profile, same(fixtureProfile));
  });

  test('con "mantener sesión" guarda el nuevo refresh token', () async {
    final storage = FakeSessionStorage(refreshToken: 'refresh-token');
    final store = SessionStore()..start(fixtureSession, fixtureProfile);

    await RefreshSession(FakeAuthRepository(), store, storage)();

    expect(storage.refreshToken, fixtureRefreshedSession.refreshToken);
  });

  test('sin "mantener sesión" no guarda nada', () async {
    final storage = FakeSessionStorage();
    final store = SessionStore()..start(fixtureSession, fixtureProfile);

    await RefreshSession(FakeAuthRepository(), store, storage)();

    expect(storage.refreshToken, isNull);
  });

  test('si el almacenamiento falla la sesión igual se renueva', () async {
    final store = SessionStore()..start(fixtureSession, fixtureProfile);

    final renewed = await RefreshSession(
      FakeAuthRepository(),
      store,
      FakeSessionStorage(failing: true),
    )();

    expect(renewed, isTrue);
    expect(store.session, same(fixtureRefreshedSession));
  });

  test('si el refresh token ya no sirve devuelve false', () async {
    final store = SessionStore()..start(fixtureSession, fixtureProfile);

    final renewed = await RefreshSession(
      FakeAuthRepository(
        refreshFailure: const AuthFailure('vencido', isUnauthorized: true),
      ),
      store,
      FakeSessionStorage(),
    )();

    expect(renewed, isFalse);
    expect(store.session, same(fixtureSession));
  });
}
