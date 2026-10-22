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
/// sesión con [renewSession] y repite la petición una sola vez. Cada
/// repositorio traduce las demás respuestas a sus propios errores.
///
/// El refresh token es de un solo uso, así que las renovaciones no se pisan:
/// - Si varias peticiones reciben 401 a la vez, se hace **una** renovación y
///   todas esperan ese mismo resultado.
/// - Si una petición salió con un token que ya fue reemplazado mientras
///   viajaba, se repite con el token nuevo sin volver a renovar.
///
/// Para que esto aplique entre repositorios, la app usa una sola instancia.
/// [renewSession] devuelve `false` si la sesión venció y lanza
/// [BackendUnreachableException] si no hubo red (`RefreshSession.renew`).
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

  /// Renovación en curso; `null` si no hay ninguna.
  Future<bool>? _renewal;

  /// Lanza [SessionExpiredException] o [BackendUnreachableException]; las
  /// demás respuestas (incluidos 4xx/5xx) se devuelven tal cual.
  Future<http.Response> send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final token = _currentToken();
    final response = await _send(request, token);
    if (response.statusCode != 401) return response;

    final latest = _accessToken();
    final alreadyRenewed =
        latest != null && latest.isNotEmpty && latest != token;
    if (!alreadyRenewed && !await _renewOnce()) {
      throw const SessionExpiredException();
    }
    final retried = await _send(request, _currentToken());
    if (retried.statusCode == 401) throw const SessionExpiredException();
    return retried;
  }

  /// Una sola renovación a la vez: las demás esperan la que está en curso.
  Future<bool> _renewOnce() {
    final pending = _renewal;
    if (pending != null) return pending;
    final renewal = _renewSafely();
    _renewal = renewal;
    return renewal.whenComplete(() => _renewal = null);
  }

  /// Si la renovación no pudo contactar al backend, se informa como tal: la
  /// sesión puede seguir siendo válida y no hay que sacar al usuario.
  Future<bool> _renewSafely() async {
    try {
      return await _renewSession();
    } on BackendUnreachableException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  String _currentToken() {
    final token = _accessToken();
    if (token == null || token.isEmpty) throw const SessionExpiredException();
    return token;
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
    String token,
  ) async {
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
