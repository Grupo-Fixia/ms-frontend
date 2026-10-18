import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/service_category.dart';
import '../../../../core/http/authorized_http.dart';
import '../application/ports/technician_specialties_repository.dart';
import '../domain/technician_specialties.dart';
import '../domain/technician_specialties_exceptions.dart';

/// Especialidades del técnico contra ms-users (GC-325, API de GC-322).
///
/// Contrato (`docs/openapi.yaml` de ms-users):
/// - `GET /api/users/service-categories` → `200 [{code, name}]` (cualquier
///   rol autenticado).
/// - `GET /api/users/technicians/me/categories` → `200 {categories,
///   updatedAt}`; lista vacía si no ha seleccionado ninguna.
/// - `PUT` del mismo recurso con `{categories}` → `200` con lo guardado;
///   `400` con `errors[{field, message}]`.
/// - `403` el rol no es técnico, `404` la cuenta no tiene perfil de técnico.
class HttpTechnicianSpecialtiesRepository
    implements TechnicianSpecialtiesRepository {
  HttpTechnicianSpecialtiesRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _catalogEndpoint = baseUrl.resolve(catalogPath),
        _specialtiesEndpoint = baseUrl.resolve(specialtiesPath),
        _http = authorizedHttp;

  static const catalogPath = '/api/users/service-categories';
  static const specialtiesPath = '/api/users/technicians/me/categories';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'Esta sección es solo para técnicos.';
  static const notFoundMessage =
      'No encontramos tu perfil de técnico. Escríbenos a soporte.';
  static const invalidDataMessage = 'Revisa las especialidades seleccionadas.';
  static const unexpectedErrorMessage =
      'No pudimos completar la acción. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _catalogEndpoint;
  final Uri _specialtiesEndpoint;
  final AuthorizedHttp _http;

  @override
  Future<List<ServiceCategoryOption>> fetchCatalog() async {
    final response = await _send(
      (headers) => _client.get(_catalogEndpoint, headers: headers),
    );
    _throwOnError(response);
    final decoded = _decode(response);
    if (decoded is! List) {
      throw const TechnicianSpecialtiesFailure(unexpectedErrorMessage);
    }
    final options = <ServiceCategoryOption>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final category = ServiceCategory.fromApi(item['code'] as String?);
      if (category == null) continue; // Categoría que el frontend no conoce.
      final name = item['name'];
      options.add(
        ServiceCategoryOption(
          category: category,
          name: name is String && name.trim().isNotEmpty
              ? name.trim()
              : category.label,
        ),
      );
    }
    return options;
  }

  @override
  Future<TechnicianSpecialties> fetchSpecialties() async {
    final response = await _send(
      (headers) => _client.get(_specialtiesEndpoint, headers: headers),
    );
    return _specialtiesFrom(response);
  }

  @override
  Future<TechnicianSpecialties> updateSpecialties(
    Set<ServiceCategory> categories,
  ) async {
    final body = jsonEncode({
      'categories': [
        for (final category in ServiceCategory.values)
          if (categories.contains(category)) category.apiValue,
      ],
    });
    final response = await _send(
      (headers) => _client.put(
        _specialtiesEndpoint,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=utf-8'
        },
        body: body,
      ),
    );
    return _specialtiesFrom(response);
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const TechnicianSpecialtiesFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    } on BackendUnreachableException {
      throw const TechnicianSpecialtiesFailure(connectionErrorMessage);
    }
  }

  TechnicianSpecialties _specialtiesFrom(http.Response response) {
    _throwOnError(response);
    final json = _decode(response);
    if (json is! Map) {
      throw const TechnicianSpecialtiesFailure(unexpectedErrorMessage);
    }
    final categories = json['categories'];
    if (categories is! List) {
      throw const TechnicianSpecialtiesFailure(unexpectedErrorMessage);
    }
    final updatedAt = json['updatedAt'];
    return TechnicianSpecialties(
      categories: categories
          .whereType<String>()
          .map(ServiceCategory.fromApi)
          .whereType<ServiceCategory>()
          .toSet(),
      updatedAt: updatedAt is String ? DateTime.tryParse(updatedAt) : null,
    );
  }

  void _throwOnError(http.Response response) {
    switch (response.statusCode) {
      case 200:
        return;
      case 400:
        throw TechnicianSpecialtiesFailure(
          invalidDataMessage,
          fieldErrors: _fieldErrors(_decode(response)),
        );
      case 403:
        throw const TechnicianSpecialtiesFailure(forbiddenMessage);
      case 404:
        throw const TechnicianSpecialtiesFailure(notFoundMessage);
      default:
        throw const TechnicianSpecialtiesFailure(unexpectedErrorMessage);
    }
  }

  /// `errors[{field, message}]` del ProblemDetail; `categories[0]` se agrupa
  /// en `categories` y, si un campo trae varios errores, se muestra el primero.
  Map<String, String> _fieldErrors(Object? body) {
    final fieldErrors = <String, String>{};
    final errors = body is Map ? body['errors'] : null;
    if (errors is List) {
      for (final error in errors) {
        if (error is! Map) continue;
        final field = error['field'];
        final message = error['message'];
        if (field is String && message is String && message.trim().isNotEmpty) {
          fieldErrors.putIfAbsent(field.split('[').first, () => message.trim());
        }
      }
    }
    return fieldErrors;
  }

  /// Siempre UTF-8, para que las tildes no lleguen dañadas (TD V1, DEF-02).
  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
