import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/service_category.dart';
import '../application/ports/technician_profile_repository.dart';
import '../domain/professional_profile_update.dart';
import '../domain/technician_profile.dart';
import '../domain/technician_profile_exceptions.dart';
import '../domain/verification_status.dart';

/// Perfil profesional contra `/api/users/technicians/me/profile` de ms-users
/// (GC-264). El técnico se toma del token, nunca de la petición.
///
/// Contrato (ms-users `TechnicianProfileController`):
/// - `GET` → `200` con el perfil (campos profesionales en null si están
///   vacíos).
/// - `PUT` → `200` con el perfil guardado; `400` con `errors[{field,
///   message}]`.
/// - `401` sesión inválida, `403` el rol no es técnico, `404` la cuenta no
///   tiene perfil de técnico.
///
/// Si el access token venció (401) se renueva una vez con [renewSession] y se
/// repite la llamada; si tampoco sirve, la sesión expiró.
class HttpTechnicianProfileRepository implements TechnicianProfileRepository {
  HttpTechnicianProfileRepository({
    required http.Client client,
    required Uri baseUrl,
    required String? Function() accessToken,
    required Future<bool> Function() renewSession,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client,
        _endpoint = baseUrl.resolve(path),
        _accessToken = accessToken,
        _renewSession = renewSession;

  static const path = '/api/users/technicians/me/profile';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'Esta sección es solo para técnicos.';
  static const notFoundMessage =
      'No encontramos tu perfil de técnico. Escríbenos a soporte.';
  static const invalidDataMessage = 'Revisa los datos marcados en el perfil.';
  static const unexpectedErrorMessage =
      'No pudimos completar la acción. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _endpoint;
  final String? Function() _accessToken;
  final Future<bool> Function() _renewSession;
  final Duration timeout;

  @override
  Future<TechnicianProfile> fetchProfile() async {
    final response = await _authorized(
      (headers) => _client.get(_endpoint, headers: headers),
    );
    return _profileFrom(response);
  }

  @override
  Future<TechnicianProfile> updateProfile(
    ProfessionalProfileUpdate update,
  ) async {
    final body = jsonEncode({
      'professionalDescription': update.professionalDescription.trim(),
      'yearsOfExperience': update.yearsOfExperience,
      'categories': [
        for (final category in ServiceCategory.values)
          if (update.categories.contains(category)) category.apiValue,
      ],
    });
    final response = await _authorized(
      (headers) => _client.put(
        _endpoint,
        headers: {...headers, 'Content-Type': 'application/json; charset=utf-8'},
        body: body,
      ),
    );
    return _profileFrom(response);
  }

  /// Envía con el access token vigente y, ante un 401, renueva la sesión y
  /// reintenta una sola vez.
  Future<http.Response> _authorized(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    var response = await _send(request, _accessToken());
    if (response.statusCode != 401) return response;
    if (!await _renewSession()) {
      throw const TechnicianProfileFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    }
    response = await _send(request, _accessToken());
    if (response.statusCode == 401) {
      throw const TechnicianProfileFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    }
    return response;
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
    String? accessToken,
  ) async {
    if (accessToken == null || accessToken.isEmpty) {
      throw const TechnicianProfileFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    }
    try {
      return await request({
        'Accept': 'application/json, application/problem+json',
        'Authorization': 'Bearer $accessToken',
      }).timeout(timeout);
    } on TimeoutException {
      throw const TechnicianProfileFailure(connectionErrorMessage);
    } on http.ClientException {
      throw const TechnicianProfileFailure(connectionErrorMessage);
    }
  }

  TechnicianProfile _profileFrom(http.Response response) {
    switch (response.statusCode) {
      case 200:
        final json = _decodeObject(response);
        final profile = json == null ? null : _parseProfile(json);
        if (profile == null) {
          throw const TechnicianProfileFailure(unexpectedErrorMessage);
        }
        return profile;
      case 400:
        final fieldErrors = _fieldErrors(_decodeObject(response));
        throw TechnicianProfileFailure(
          invalidDataMessage,
          fieldErrors: fieldErrors,
        );
      case 403:
        throw const TechnicianProfileFailure(forbiddenMessage);
      case 404:
        throw const TechnicianProfileFailure(notFoundMessage);
      default:
        throw const TechnicianProfileFailure(unexpectedErrorMessage);
    }
  }

  /// Convierte la respuesta de ms-users; `null` si falta el id del técnico.
  /// Las categorías que el frontend no conoce se ignoran.
  TechnicianProfile? _parseProfile(Map<String, dynamic> json) {
    final technicianId = json['technicianId'];
    if (technicianId is! String || technicianId.isEmpty) return null;
    final description = json['professionalDescription'];
    final years = json['yearsOfExperience'];
    final categories = json['categories'];
    final status = json['verificationStatus'];
    final updatedAt = json['updatedAt'];
    return TechnicianProfile(
      technicianId: technicianId,
      verificationStatus:
          status is String ? VerificationStatus.fromApi(status) : null,
      professionalDescription: description is String ? description : null,
      yearsOfExperience: years is num ? years.toInt() : null,
      categories: categories is List
          ? categories
              .whereType<String>()
              .map(ServiceCategory.fromApi)
              .whereType<ServiceCategory>()
              .toSet()
          : const {},
      updatedAt: updatedAt is String ? DateTime.tryParse(updatedAt) : null,
    );
  }

  /// `errors[{field, message}]` del ProblemDetail; si un campo trae varios
  /// errores, se muestra el primero.
  Map<String, String> _fieldErrors(Map<String, dynamic>? body) {
    final fieldErrors = <String, String>{};
    final errors = body?['errors'];
    if (errors is List) {
      for (final error in errors) {
        if (error is! Map) continue;
        final field = error['field'];
        final message = error['message'];
        if (field is String && message is String && message.trim().isNotEmpty) {
          // `categories[0]` → `categories`: el error se muestra en el grupo.
          final name = field.split('[').first;
          fieldErrors.putIfAbsent(name, () => message.trim());
        }
      }
    }
    return fieldErrors;
  }

  /// Siempre UTF-8, para que las tildes no lleguen dañadas (TD V1, DEF-02).
  Map<String, dynamic>? _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
