import 'dart:async';

import 'package:ms_frontend/features/auth/login/application/ports/auth_repository.dart';
import 'package:ms_frontend/features/auth/login/application/ports/session_storage.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_session.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';

const fixtureSession = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresIn: Duration(seconds: 900),
);

/// Sesión que devuelve `refresh`: el refresh token rota en cada canje.
const fixtureRefreshedSession = AuthSession(
  accessToken: 'access-token-2',
  refreshToken: 'refresh-token-2',
  expiresIn: Duration(seconds: 900),
);

const fixtureProfile = UserProfile(
  id: '3f6c1c0e-5d0a-4a8f-9d6e-0a1b2c3d4e5f',
  email: 'ana@fixia.com',
  firstName: 'Ana',
  lastName: 'Pérez',
  role: UserRole.client,
);

/// Repositorio de prueba: guarda lo recibido y puede fallar o demorarse.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.loginFailure,
    this.profileFailure,
    this.logoutFailure,
    this.refreshFailure,
    this.pendingLogin,
    this.pendingLogout,
    this.failOnlyFirstLogout = false,
    this.profile = fixtureProfile,
  });

  /// Cuenta que devuelve `fetchProfile` (por defecto, una clienta).
  final UserProfile profile;

  AuthFailure? loginFailure;
  final AuthFailure? profileFailure;
  final AuthFailure? logoutFailure;
  final AuthFailure? refreshFailure;
  final Completer<void>? pendingLogin;
  final Completer<void>? pendingLogout;

  /// Con `true`, `logoutFailure` solo se lanza en el primer cierre de sesión
  /// (simula un access token vencido que se renueva y luego sí se revoca).
  final bool failOnlyFirstLogout;

  int loginCalls = 0;
  int profileCalls = 0;
  int logoutCalls = 0;
  int refreshCalls = 0;
  String? lastRefreshToken;
  String? lastEmail;
  String? lastPassword;
  String? lastProfileToken;
  AuthSession? loggedOutSession;
  final List<AuthSession> loggedOutSessions = [];

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    lastEmail = email;
    lastPassword = password;
    await pendingLogin?.future;
    final failure = loginFailure;
    if (failure != null) throw failure;
    return fixtureSession;
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshCalls++;
    lastRefreshToken = refreshToken;
    final failure = refreshFailure;
    if (failure != null) throw failure;
    return fixtureRefreshedSession;
  }

  @override
  Future<UserProfile> fetchProfile(String accessToken) async {
    profileCalls++;
    lastProfileToken = accessToken;
    final failure = profileFailure;
    if (failure != null) throw failure;
    return profile;
  }

  @override
  Future<void> logout(AuthSession session) async {
    logoutCalls++;
    loggedOutSession = session;
    loggedOutSessions.add(session);
    await pendingLogout?.future;
    final failure = logoutFailure;
    if (failure != null && (!failOnlyFirstLogout || logoutCalls == 1)) {
      throw failure;
    }
  }
}

/// Almacenamiento de prueba en memoria; puede simular un navegador que no
/// deja leer ni escribir.
class FakeSessionStorage implements SessionStorage {
  FakeSessionStorage({this.refreshToken, this.failing = false});

  String? refreshToken;
  final bool failing;
  int clearCalls = 0;

  void _check() {
    if (failing) throw StateError('almacenamiento no disponible');
  }

  @override
  Future<String?> readRefreshToken() async {
    _check();
    return refreshToken;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    _check();
    refreshToken = token;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    _check();
    refreshToken = null;
  }
}
