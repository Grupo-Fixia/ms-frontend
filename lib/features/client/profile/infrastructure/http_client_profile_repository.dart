import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/http/authorized_http.dart';
import '../application/ports/client_profile_repository.dart';
import '../domain/client_profile.dart';
import '../domain/client_profile_exceptions.dart';
import '../domain/client_profile_update.dart';

/// Perfil del cliente contra ms-users (GC-320, API de GC-317).
///
/// Contrato (`docs/openapi.yaml` de ms-users):
/// - `GET /api/users/clients/me/profile` → `200` con el perfil. El cliente
///   sale del token.
/// - `PUT` del mismo recurso con `{firstName, lastName, phone}` → `200` con
///   el perfil guardado; `400` con `errors[{field, message}]`. El correo y el
///   documento no se editan.
/// - `403` el rol no es cliente.
class HttpClientProfileRepository implements ClientProfileRepository {
  HttpClientProfileRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _endpoint = baseUrl.resolve(path),
        _http = authorizedHttp;

  static const path = '/api/users/clients/me/profile';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'Esta sección es solo para clientes.';
  static const notFoundMessage =
      'No encontramos tu perfil. Escríbenos a soporte.';
  static const invalidDataMessage = 'Revisa los datos marcados.';
  static const unexpectedErrorMessage =
      'No pudimos completar la acción. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _endpoint;
  final AuthorizedHttp _http;

  @override
  Future<ClientProfile> fetchProfile() async {
    final response = await _send(
      (headers) => _client.get(_endpoint, headers: headers),
    );
    return _profileFrom(response);
  }

  @override
  Future<ClientProfile> updateProfile(ClientProfileUpdate update) async {
    final response = await _send(
      (headers) => _client.put(
        _endpoint,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'firstName': update.firstName,
          'lastName': update.lastName,
          'phone': update.phone,
        }),
      ),
    );
    return _profileFrom(response);
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const ClientProfileFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    } on BackendUnreachableException {
      throw const ClientProfileFailure(connectionErrorMessage);
    }
  }

  ClientProfile _profileFrom(http.Response response) {
    final body = _decode(response);
    switch (response.statusCode) {
      case 200:
        final profile = _parse(body);
        if (profile == null) {
          throw const ClientProfileFailure(unexpectedErrorMessage);
        }
        return profile;
      case 400:
        final fieldErrors = _fieldErrors(body);
        final detail = body is Map ? body['detail'] : null;
        throw ClientProfileFailure(
          fieldErrors.isEmpty && detail is String && detail.trim().isNotEmpty
              ? detail.trim()
              : invalidDataMessage,
          fieldErrors: fieldErrors,
        );
      case 403:
        throw const ClientProfileFailure(forbiddenMessage);
      case 404:
        throw const ClientProfileFailure(notFoundMessage);
      default:
        throw const ClientProfileFailure(unexpectedErrorMessage);
    }
  }

  /// `null` si falta el id o el correo.
  ClientProfile? _parse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final email = json['email'];
    if (id is! String || id.isEmpty || email is! String) return null;
    final createdAt = json['createdAt'];
    return ClientProfile(
      id: id,
      email: email,
      firstName: _string(json['firstName']) ?? '',
      lastName: _string(json['lastName']) ?? '',
      phone: _string(json['phone']) ?? '',
      documentType: _string(json['documentType']),
      documentNumber: _string(json['documentNumber']),
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }

  /// `errors[{field, message}]` del ProblemDetail; si un campo trae varios
  /// errores, se muestra el primero.
  Map<String, String> _fieldErrors(Object? body) {
    final fieldErrors = <String, String>{};
    final errors = body is Map ? body['errors'] : null;
    if (errors is List) {
      for (final error in errors) {
        if (error is! Map) continue;
        final field = error['field'];
        final message = error['message'];
        if (field is String && message is String && message.trim().isNotEmpty) {
          fieldErrors.putIfAbsent(field, () => message.trim());
        }
      }
    }
    return fieldErrors;
  }

  String? _string(Object? value) => value is String ? value : null;

  /// Siempre UTF-8, para que las tildes no lleguen dañadas (TD V1, DEF-02).
  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
