import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/service_category.dart';
import '../../../../core/http/authorized_http.dart';
import '../application/ports/opportunity_repository.dart';
import '../domain/opportunity.dart';
import '../domain/opportunity_exceptions.dart';

/// Oportunidades compatibles del técnico contra ms-services (GC-340, API de
/// GC-338).
///
/// Contrato (`docs/openapi.yaml` de ms-services):
/// - `GET /api/services/opportunities?limit=&cursor=` → `200
///   {items, nextCursor}`. Solo rol técnico. La compatibilidad (categoría,
///   zona y disponibilidad) la decide ms-users.
/// - `400` límite o cursor inválidos; `403` el rol no es técnico; `503` no
///   se pudo verificar la elegibilidad con ms-users.
class HttpOpportunityRepository implements OpportunityRepository {
  HttpOpportunityRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _endpoint = baseUrl.resolve(path),
        _http = authorizedHttp;

  static const path = '/api/services/opportunities';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'Esta sección es solo para técnicos.';
  static const invalidQueryMessage =
      'La lista de oportunidades cambió. Vuelve a cargarla.';
  static const eligibilityUnavailableMessage =
      'No pudimos revisar qué solicitudes te corresponden. Inténtalo en unos minutos.';
  static const unexpectedErrorMessage =
      'No pudimos cargar las oportunidades. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _endpoint;
  final AuthorizedHttp _http;

  @override
  Future<OpportunityPage> fetchPage(
      {required int limit, String? cursor}) async {
    final uri = _endpoint.replace(queryParameters: {
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    });
    final http.Response response;
    try {
      response = await _http.send(
        (headers) => _client.get(uri, headers: headers),
      );
    } on SessionExpiredException {
      throw const OpportunityFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    } on BackendUnreachableException {
      throw const OpportunityFailure(connectionErrorMessage);
    }

    switch (response.statusCode) {
      case 200:
        return _parsePage(_decode(response));
      case 400:
        throw const OpportunityFailure(invalidQueryMessage);
      case 403:
        throw const OpportunityFailure(forbiddenMessage);
      case 503:
        throw const OpportunityFailure(eligibilityUnavailableMessage);
      default:
        throw const OpportunityFailure(unexpectedErrorMessage);
    }
  }

  OpportunityPage _parsePage(Object? json) {
    if (json is! Map || json['items'] is! List) {
      throw const OpportunityFailure(unexpectedErrorMessage);
    }
    final next = json['nextCursor'];
    return OpportunityPage(
      items: List.unmodifiable(
        (json['items'] as List).map(_parse).whereType<Opportunity>(),
      ),
      nextCursor: next is String && next.isNotEmpty ? next : null,
    );
  }

  /// `null` si faltan datos esenciales o la categoría es desconocida: no se
  /// presenta como oportunidad válida.
  Opportunity? _parse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final category = ServiceCategory.fromApi(_string(json['category']));
    final city = json['city'];
    final zone = json['zone'];
    final expectedAt = _date(json['expectedAt']);
    if (id is! String ||
        id.isEmpty ||
        category == null ||
        city is! String ||
        zone is! String ||
        expectedAt == null) {
      return null;
    }
    final description = json['description'];
    return Opportunity(
      id: id,
      category: category,
      description: description is String ? description : '',
      city: city,
      zone: zone,
      expectedAt: expectedAt,
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      publishedAt: _date(json['publishedAt']),
    );
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
