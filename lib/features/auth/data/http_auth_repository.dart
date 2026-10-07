import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/ports/auth_repository.dart';
import '../domain/auth_exceptions.dart';
import '../domain/auth_session.dart';
import '../domain/user_profile.dart';

/// Implementación HTTP del puerto contra ms-users (`/api/users/...`).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required http.Client client,
    required Uri baseUrl,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client,
        _baseUrl = baseUrl;

  final http.Client _client;
  final Uri _baseUrl;
  final Duration timeout;

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  static const _connectionError =
      'No fue posible conectar con el servicio. Inténtalo de nuevo.';
  static const _sessionExpired = 'Tu sesión expiró. Inicia sesión de nuevo.';

  Uri _uri(String path) => _baseUrl.resolve('/api/users$path');

  Map<String, String> _bearer(String accessToken) => {
        ..._jsonHeaders,
        'Authorization': 'Bearer $accessToken',
      };

  /// Ejecuta la llamada y convierte cualquier fallo de red en `AuthFailure`.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on Exception {
      throw const AuthFailure(_connectionError);
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri('/auth/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );

    if (response.statusCode == 200) {
      final session = _parseSession(response);
      if (session != null) return session;
    }
    if (response.statusCode == 401) {
      throw AuthFailure(
        _detail(response) ?? 'Correo o contraseña incorrectos.',
        isUnauthorized: true,
      );
    }
    if (response.statusCode == 400) {
      throw AuthFailure(
        _detail(response) ?? 'Revisa los datos ingresados.',
        fieldErrors: _fieldErrors(response),
      );
    }
    throw const AuthFailure(
      'No fue posible iniciar sesión. Inténtalo más tarde.',
    );
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _send(
      () => _client.post(
        _uri('/auth/refresh'),
        headers: _jsonHeaders,
        body: jsonEncode({'refreshToken': refreshToken}),
      ),
    );

    if (response.statusCode == 200) {
      final session = _parseSession(response);
      if (session != null) return session;
    }
    if (response.statusCode == 401) {
      throw const AuthFailure(_sessionExpired, isUnauthorized: true);
    }
    throw const AuthFailure(
      'No fue posible restaurar tu sesión. Inténtalo más tarde.',
    );
  }

  @override
  Future<UserProfile> fetchProfile(String accessToken) async {
    final response = await _send(
      () => _client.get(_uri('/me'), headers: _bearer(accessToken)),
    );

    if (response.statusCode == 200) {
      final json = _decodeObject(response);
      final id = json?['id'];
      final email = json?['email'];
      if (id is String && email is String) {
        return UserProfile(
          id: id,
          email: email,
          firstName: _string(json?['firstName']),
          lastName: _string(json?['lastName']),
          role: UserRole.fromApi(json?['role'] as String?),
        );
      }
    }
    if (response.statusCode == 401) {
      throw const AuthFailure(_sessionExpired, isUnauthorized: true);
    }
    throw const AuthFailure(
      'No fue posible cargar tu cuenta. Inténtalo más tarde.',
    );
  }

  @override
  Future<void> logout(AuthSession session) async {
    final response = await _send(
      () => _client.post(
        _uri('/auth/logout'),
        headers: _bearer(session.accessToken),
        body: jsonEncode({'refreshToken': session.refreshToken}),
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 204) return;
    if (response.statusCode == 401) {
      throw const AuthFailure(_sessionExpired, isUnauthorized: true);
    }
    throw const AuthFailure(
      'No fue posible cerrar la sesión. Inténtalo más tarde.',
    );
  }

  /// Tokens de `login` y `refresh` (mismo `TokenResponse`); `null` si falta alguno.
  AuthSession? _parseSession(http.Response response) {
    final json = _decodeObject(response);
    final accessToken = json?['accessToken'];
    final refreshToken = json?['refreshToken'];
    if (accessToken is! String || refreshToken is! String) return null;
    final expiresIn = json?['expiresIn'];
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: Duration(seconds: expiresIn is num ? expiresIn.toInt() : 0),
    );
  }

  String _string(Object? value) => value is String ? value : '';

  /// El cuerpo se decodifica como UTF-8 a mano: `application/problem+json`
  /// no declara charset y `response.body` lo leería como Latin-1.
  Map<String, dynamic>? _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// `detail` del ProblemDetail de ms-users.
  String? _detail(http.Response response) {
    final detail = _decodeObject(response)?['detail'];
    return detail is String && detail.trim().isNotEmpty ? detail.trim() : null;
  }

  /// `errors[{field, message}]` del ProblemDetail de ms-users.
  Map<String, String> _fieldErrors(http.Response response) {
    final errors = _decodeObject(response)?['errors'];
    if (errors is! List) return const {};
    final result = <String, String>{};
    for (final error in errors.whereType<Map<String, dynamic>>()) {
      final field = error['field'];
      final message = error['message'];
      if (field is String && message is String) result[field] = message;
    }
    return result;
  }
}
