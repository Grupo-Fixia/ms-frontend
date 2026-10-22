import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/service_category.dart';
import '../../../../core/http/authorized_http.dart';
import '../application/ports/service_request_repository.dart';
import '../domain/applicant.dart';
import '../domain/service_request.dart';
import '../domain/service_request_exceptions.dart';

/// Solicitudes de servicio del cliente contra ms-services (GC-335, API de
/// GC-333).
///
/// Contrato (`docs/openapi.yaml` de ms-services):
/// - `POST /api/services/requests` → `201` con la solicitud `PUBLISHED`. El
///   cliente sale del token.
/// - `GET /api/services/requests` → `200` con las del cliente, la más
///   reciente primero.
/// - `GET /api/services/requests/{id}` → `200`; `404` si no existe o es de
///   otro cliente.
/// - `GET /api/services/requests/{id}/applications` → `200` con los
///   postulantes en orden de llegada (GC-347).
/// - `POST /api/services/requests/{id}/applications/{applicationId}/selection`
///   → `200` con la solicitud en `PROVIDER_SELECTED` (GC-348); `409` si ya
///   no admite seleccionar prestador.
/// - `400` con `errors[{field, message}]` (`approximateLocation.city`) o
///   solo con `detail` para reglas de negocio. `403` el rol no es cliente.
/// - `404` con título "Postulación no encontrada" cuando la postulación no
///   es de esa solicitud; si no, la solicitud no existe o es de otro cliente.
class HttpServiceRequestRepository implements ServiceRequestRepository {
  HttpServiceRequestRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _endpoint = baseUrl.resolve(path),
        _http = authorizedHttp;

  static const path = '/api/services/requests';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'Esta sección es solo para clientes.';
  static const notFoundMessage = 'No encontramos esa solicitud.';
  static const applicationNotFoundMessage =
      'Ese prestador no está entre los postulantes de la solicitud.';
  static const notSelectableMessage =
      'Esta solicitud ya no admite seleccionar prestador.';
  static const invalidDataMessage = 'Revisa los datos marcados.';
  static const unexpectedErrorMessage =
      'No pudimos completar la acción. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _endpoint;
  final AuthorizedHttp _http;

  @override
  Future<ServiceRequest> publish(NewServiceRequest request) async {
    final approximate = request.approximateLocation;
    final exact = request.exactLocation;
    final body = jsonEncode({
      'category': request.category?.apiValue,
      'description': request.description,
      'approximateLocation': {
        'city': approximate.city,
        'zone': approximate.zone,
        if (approximate.latitude != null) 'latitude': approximate.latitude,
        if (approximate.longitude != null) 'longitude': approximate.longitude,
      },
      if (exact != null)
        'exactLocation': {
          'address': exact.address,
          if (exact.latitude != null) 'latitude': exact.latitude,
          if (exact.longitude != null) 'longitude': exact.longitude,
        },
      'expectedAt': request.expectedAt?.toUtc().toIso8601String(),
      if (request.photoKeys.isNotEmpty) 'photoKeys': request.photoKeys,
    });
    final response = await _send(
      (headers) => _client.post(
        _endpoint,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: body,
      ),
    );
    _throwOnError(response, success: 201);
    return _requireRequest(_decode(response));
  }

  @override
  Future<List<ServiceRequest>> listMine() async {
    final response = await _send(
      (headers) => _client.get(_endpoint, headers: headers),
    );
    _throwOnError(response);
    final json = _decode(response);
    if (json is! List) {
      throw const ServiceRequestFailure(unexpectedErrorMessage);
    }
    return List.unmodifiable(
        json.map(_parseRequest).whereType<ServiceRequest>());
  }

  @override
  Future<ServiceRequest> getMine(String id) async {
    final response = await _send(
      (headers) => _client.get(_resource([id]), headers: headers),
    );
    _throwOnError(response);
    return _requireRequest(_decode(response));
  }

  @override
  Future<List<Applicant>> listApplicants(String requestId) async {
    final response = await _send(
      (headers) => _client.get(
        _resource([requestId, 'applications']),
        headers: headers,
      ),
    );
    _throwOnError(response);
    final json = _decode(response);
    if (json is! List) {
      throw const ServiceRequestFailure(unexpectedErrorMessage);
    }
    return List.unmodifiable(json.map(_parseApplicant).whereType<Applicant>());
  }

  @override
  Future<ServiceRequest> selectProvider(
    String requestId,
    String applicationId,
  ) async {
    final response = await _send(
      (headers) => _client.post(
        _resource([requestId, 'applications', applicationId, 'selection']),
        headers: headers,
      ),
    );
    _throwOnError(response);
    return _requireRequest(_decode(response));
  }

  Uri _resource(List<String> segments) =>
      _endpoint.replace(pathSegments: [..._endpoint.pathSegments, ...segments]);

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const ServiceRequestFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    } on BackendUnreachableException {
      throw const ServiceRequestFailure(connectionErrorMessage);
    }
  }

  void _throwOnError(http.Response response, {int success = 200}) {
    if (response.statusCode == success) return;
    switch (response.statusCode) {
      case 400:
        final body = _decode(response);
        final fieldErrors = _fieldErrors(body);
        final detail = body is Map ? body['detail'] : null;
        throw ServiceRequestFailure(
          fieldErrors.isEmpty && detail is String && detail.trim().isNotEmpty
              ? detail.trim()
              : invalidDataMessage,
          fieldErrors: fieldErrors,
        );
      case 403:
        throw const ServiceRequestFailure(forbiddenMessage);
      case 404:
        final title = _problemTitle(response);
        throw ServiceRequestFailure(
          title == 'Postulación no encontrada'
              ? applicationNotFoundMessage
              : notFoundMessage,
        );
      case 409:
        throw const ServiceRequestFailure(notSelectableMessage);
      default:
        throw const ServiceRequestFailure(unexpectedErrorMessage);
    }
  }

  String? _problemTitle(http.Response response) {
    final body = _decode(response);
    final title = body is Map ? body['title'] : null;
    return title is String ? title : null;
  }

  /// `null` si faltan datos esenciales o el estado es desconocido.
  Applicant? _parseApplicant(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final providerId = json['providerId'];
    final status = ApplicationStatus.fromApi(_string(json['status']));
    if (id is! String ||
        id.isEmpty ||
        providerId is! String ||
        providerId.isEmpty ||
        status == null) {
      return null;
    }
    return Applicant(
      id: id,
      providerId: providerId,
      status: status,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  ServiceRequest _requireRequest(Object? json) {
    final request = _parseRequest(json);
    if (request == null) {
      throw const ServiceRequestFailure(unexpectedErrorMessage);
    }
    return request;
  }

  /// `null` si faltan datos esenciales o traen valores que el frontend no
  /// conoce (categoría o estado nuevos).
  ServiceRequest? _parseRequest(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final category = ServiceCategory.fromApi(_string(json['category']));
    final status = ServiceRequestStatus.fromApi(_string(json['status']));
    final approximate = _approximate(json['approximateLocation']);
    final expectedAt = _date(json['expectedAt']);
    if (id is! String ||
        id.isEmpty ||
        category == null ||
        status == null ||
        approximate == null ||
        expectedAt == null) {
      return null;
    }
    final description = json['description'];
    final photoKeys = json['photoKeys'];
    final selected = json['selectedProviderId'];
    return ServiceRequest(
      id: id,
      category: category,
      description: description is String ? description : '',
      status: status,
      approximateLocation: approximate,
      expectedAt: expectedAt,
      exactLocation: _exact(json['exactLocation']),
      photoKeys: photoKeys is List
          ? List.unmodifiable(photoKeys.whereType<String>())
          : const [],
      selectedProviderId: selected is String ? selected : null,
      publishedAt: _date(json['publishedAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  ApproximateLocation? _approximate(Object? json) {
    if (json is! Map) return null;
    final city = json['city'];
    final zone = json['zone'];
    if (city is! String || zone is! String) return null;
    return ApproximateLocation(
      city: city,
      zone: zone,
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
    );
  }

  ExactLocation? _exact(Object? json) {
    if (json is! Map) return null;
    final address = json['address'];
    if (address is! String) return null;
    return ExactLocation(
      address: address,
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
    );
  }

  /// `errors[{field, message}]` del ProblemDetail. Se conservan los nombres
  /// del backend (`approximateLocation.city`) sin índices (`photoKeys[0]` →
  /// `photoKeys`); si un campo trae varios errores, se muestra el primero.
  Map<String, String> _fieldErrors(Object? body) {
    final fieldErrors = <String, String>{};
    final errors = body is Map ? body['errors'] : null;
    if (errors is List) {
      for (final error in errors) {
        if (error is! Map) continue;
        final field = error['field'];
        final message = error['message'];
        if (field is String && message is String && message.trim().isNotEmpty) {
          final name = field.replaceAll(RegExp(r'\[\d+\]'), '');
          fieldErrors.putIfAbsent(name, () => message.trim());
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
