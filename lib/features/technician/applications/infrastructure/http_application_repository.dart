import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/service_category.dart';
import '../../../../core/constants/service_request_status.dart';
import '../../../../core/http/authorized_http.dart';
import '../application/ports/application_repository.dart';
import '../domain/application_exceptions.dart';
import '../domain/service_application.dart';

/// Postulaciones del técnico contra ms-services (GC-345, API de GC-342 y
/// GC-343).
///
/// Contrato (`docs/openapi.yaml` de ms-services):
/// - `POST /api/services/applications` con `{serviceRequestId}` → `201`
///   (`APPLIED`). El técnico sale del token.
/// - `GET /api/services/applications` y `GET .../{id}` → `200`.
/// - `400` datos inválidos; `403` el rol no es técnico; `404` la solicitud o
///   la postulación no existe; `409` la solicitud ya no recibe postulaciones
///   o el técnico ya se postuló (`applicationId`); `422` no es elegible
///   (`reasons`); `503` no se pudo verificar la elegibilidad.
class HttpApplicationRepository implements ApplicationRepository {
  HttpApplicationRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _endpoint = baseUrl.resolve(path),
        _http = authorizedHttp;

  static const path = '/api/services/applications';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'Esta sección es solo para técnicos.';
  static const notFoundMessage = 'No encontramos esa solicitud o postulación.';
  static const invalidDataMessage = 'Revisa los datos de la postulación.';
  static const duplicateMessage = 'Ya te postulaste a esta solicitud.';
  static const notAvailableMessage =
      'Esta solicitud ya no recibe postulaciones.';
  static const notEligibleMessage = 'No puedes postularte a esta solicitud.';
  static const eligibilityUnavailableMessage =
      'No pudimos verificar si puedes postularte. Inténtalo en unos minutos.';
  static const unexpectedErrorMessage =
      'No pudimos completar la acción. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _endpoint;
  final AuthorizedHttp _http;

  @override
  Future<ServiceApplication> apply(String serviceRequestId) async {
    final response = await _send(
      (headers) => _client.post(
        _endpoint,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'serviceRequestId': serviceRequestId}),
      ),
    );
    _throwOnError(response, success: 201);
    return _requireApplication(_decode(response));
  }

  @override
  Future<List<ServiceApplication>> listMine() async {
    final response = await _send(
      (headers) => _client.get(_endpoint, headers: headers),
    );
    _throwOnError(response);
    final json = _decode(response);
    if (json is! List) {
      throw const ApplicationFailure(unexpectedErrorMessage);
    }
    return List.unmodifiable(
      json.map(_parseApplication).whereType<ServiceApplication>(),
    );
  }

  @override
  Future<ServiceApplication> getMine(String id) async {
    final uri = _endpoint.replace(
      pathSegments: [..._endpoint.pathSegments, id],
    );
    final response = await _send(
      (headers) => _client.get(uri, headers: headers),
    );
    _throwOnError(response);
    return _requireApplication(_decode(response));
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const ApplicationFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    } on BackendUnreachableException {
      throw const ApplicationFailure(connectionErrorMessage);
    }
  }

  void _throwOnError(http.Response response, {int success = 200}) {
    if (response.statusCode == success) return;
    final body = _decode(response);
    switch (response.statusCode) {
      case 400:
        throw ApplicationFailure(
          invalidDataMessage,
          fieldErrors: _fieldErrors(body),
        );
      case 403:
        throw const ApplicationFailure(forbiddenMessage);
      case 404:
        throw const ApplicationFailure(notFoundMessage);
      case 409:
        final existing = body is Map ? body['applicationId'] : null;
        if (existing is String && existing.isNotEmpty) {
          throw ApplicationFailure(
            duplicateMessage,
            existingApplicationId: existing,
          );
        }
        throw const ApplicationFailure(notAvailableMessage);
      case 422:
        final raw = body is Map ? body['reasons'] : null;
        final reasons = raw is List
            ? raw
                .whereType<String>()
                .map(IneligibilityReason.fromApi)
                .whereType<IneligibilityReason>()
                .toList()
            : <IneligibilityReason>[];
        throw ApplicationFailure(
          notEligibleMessage,
          // Si el backend envía motivos nuevos, igual se informa que no es
          // elegible.
          reasons: List.unmodifiable(reasons),
        );
      case 503:
        throw const ApplicationFailure(eligibilityUnavailableMessage);
      default:
        throw const ApplicationFailure(unexpectedErrorMessage);
    }
  }

  ServiceApplication _requireApplication(Object? json) {
    final application = _parseApplication(json);
    if (application == null) {
      throw const ApplicationFailure(unexpectedErrorMessage);
    }
    return application;
  }

  /// `null` si faltan datos esenciales o traen valores que el frontend no
  /// conoce (estado de postulación o categoría nuevos).
  ServiceApplication? _parseApplication(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final status = ApplicationStatus.fromApi(_string(json['status']));
    final request = _summary(json['serviceRequest']);
    if (id is! String || id.isEmpty || status == null || request == null) {
      return null;
    }
    return ServiceApplication(
      id: id,
      status: status,
      serviceRequest: request,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  ApplicationRequestSummary? _summary(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final category = ServiceCategory.fromApi(_string(json['category']));
    final city = json['city'];
    final zone = json['zone'];
    if (id is! String ||
        id.isEmpty ||
        category == null ||
        city is! String ||
        zone is! String) {
      return null;
    }
    return ApplicationRequestSummary(
      id: id,
      category: category,
      city: city,
      zone: zone,
      status: ServiceRequestStatus.fromApi(_string(json['status'])),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      expectedAt: _date(json['expectedAt']),
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

  double? _double(Object? value) => value is num ? value.toDouble() : null;

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// Siempre UTF-8, para que las tildes no lleguen dañadas (TD V1, DEF-02).
  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
