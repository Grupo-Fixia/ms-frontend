import 'dart:async';

import 'package:http/http.dart' as http;

/// La sesión ya no es válida (sin token, o el token renovado tampoco sirve):
/// hay que volver a iniciar sesión.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

/// No se pudo contactar al backend (sin red o se agotó el tiempo).
class BackendUnreachableException implements Exception {
  const BackendUnreachableException();
}

/// Envía peticiones autenticadas con el access token de la sesión.
///
/// Si el backend responde 401 (el access token dura 15 minutos) renueva la
/// sesión una sola vez con [renewSession] y repite la petición. Cada
/// repositorio traduce las demás respuestas a sus propios errores.
class AuthorizedHttp {
  AuthorizedHttp({
    required String? Function() accessToken,
    required Future<bool> Function() renewSession,
    this.timeout = const Duration(seconds: 15),
  })  : _accessToken = accessToken,
        _renewSession = renewSession;

  final String? Function() _accessToken;
  final Future<bool> Function() _renewSession;
  final Duration timeout;

  /// Lanza [SessionExpiredException] o [BackendUnreachableException]; las
  /// demás respuestas (incluidos 4xx/5xx) se devuelven tal cual.
  Future<http.Response> send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final response = await _send(request);
    if (response.statusCode != 401) return response;
    if (!await _renewSession()) throw const SessionExpiredException();
    final retried = await _send(request);
    if (retried.statusCode == 401) throw const SessionExpiredException();
    return retried;
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final token = _accessToken();
    if (token == null || token.isEmpty) throw const SessionExpiredException();
    try {
      return await request({
        'Accept': 'application/json, application/problem+json',
        'Authorization': 'Bearer $token',
      }).timeout(timeout);
    } on TimeoutException {
      throw const BackendUnreachableException();
    } on http.ClientException {
      throw const BackendUnreachableException();
    }
  }
}
