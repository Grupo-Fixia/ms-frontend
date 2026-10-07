import 'dart:async';

import 'package:ms_frontend/features/auth/application/ports/auth_repository.dart';
import 'package:ms_frontend/features/auth/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/domain/auth_session.dart';
import 'package:ms_frontend/features/auth/domain/user_profile.dart';

const fixtureSession = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
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
    this.pendingLogin,
    this.pendingLogout,
  });

  AuthFailure? loginFailure;
  final AuthFailure? profileFailure;
  final AuthFailure? logoutFailure;
  final Completer<void>? pendingLogin;
  final Completer<void>? pendingLogout;

  int loginCalls = 0;
  int profileCalls = 0;
  int logoutCalls = 0;
  String? lastEmail;
  String? lastPassword;
  String? lastProfileToken;
  AuthSession? loggedOutSession;

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
  Future<UserProfile> fetchProfile(String accessToken) async {
    profileCalls++;
    lastProfileToken = accessToken;
    final failure = profileFailure;
    if (failure != null) throw failure;
    return fixtureProfile;
  }

  @override
  Future<void> logout(AuthSession session) async {
    logoutCalls++;
    loggedOutSession = session;
    await pendingLogout?.future;
    final failure = logoutFailure;
    if (failure != null) throw failure;
  }
}
