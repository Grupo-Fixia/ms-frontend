import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/service_category.dart';
import '../../../../core/http/authorized_http.dart';
import '../domain/compatible_technician.dart';
import '../domain/service_request_exceptions.dart';

/// Técnicos compatibles con una solicitud propia (GC-474) contra ms-services,
/// que los consulta a ms-matching-geo.
///
/// Contrato: `GET /api/services/requests/{id}/compatible-technicians
/// ?limit=&cursor=` → `200 {items: [{userId, displayName, categories,
/// city}], nextCursor}`. `409` si la solicitud ya no está abierta, `404` si
/// no es del cliente, `503` si matching no responde (nunca lista vacía).
class HttpCompatibleTechniciansRepository {
  HttpCompatibleTechniciansRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _endpoint = baseUrl.resolve('/api/services/requests'),
        _http = authorizedHttp;

  static const pageSize = 20;
  static const unavailableMessage =
      'No pudimos consultar los técnicos compatibles en este momento. Inténtalo de nuevo.';
  static const closedMessage =
      'Esta solicitud ya no recibe postulaciones, así que no sugerimos técnicos.';
  static const notFoundMessage = 'No encontramos esa solicitud.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';

  final http.Client _client;
  final Uri _endpoint;
  final AuthorizedHttp _http;

  Future<CompatibleTechniciansPage> list(String requestId,
      {String? cursor}) async {
    final uri = _endpoint.replace(
      pathSegments: [
        ..._endpoint.pathSegments,
        requestId,
        'compatible-technicians',
      ],
      queryParameters: {
        'limit': '$pageSize',
        if (cursor != null) 'cursor': cursor,
      },
    );
    http.Response response;
    try {
      response =
          await _http.send((headers) => _client.get(uri, headers: headers));
    } on SessionExpiredException {
      throw const ServiceRequestFailure(sessionExpiredMessage,
          isSessionExpired: true);
    } on BackendUnreachableException {
      throw const ServiceRequestFailure(connectionErrorMessage);
    }
    switch (response.statusCode) {
      case 200:
        break;
      case 404:
        throw const ServiceRequestFailure(notFoundMessage);
      case 409:
        throw const ServiceRequestFailure(closedMessage);
      default:
        throw const ServiceRequestFailure(unavailableMessage);
    }
    Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ServiceRequestFailure(unavailableMessage);
    }
    if (json is! Map || json['items'] is! List) {
      throw const ServiceRequestFailure(unavailableMessage);
    }
    final next = json['nextCursor'];
    return CompatibleTechniciansPage(
      items: List.unmodifiable([
        for (final item in json['items'] as List)
          if (_parse(item) case final technician?) technician,
      ]),
      nextCursor: next is String && next.isNotEmpty ? next : null,
    );
  }

  CompatibleTechnician? _parse(Object? json) {
    if (json is! Map) return null;
    final id = json['userId'];
    final name = json['displayName'];
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty) {
      return null;
    }
    final categories = json['categories'];
    final city = json['city'];
    return CompatibleTechnician(
      userId: id,
      displayName: name.trim(),
      categories: [
        if (categories is List)
          for (final c in categories)
            if (ServiceCategory.fromApi(c is String ? c : null)
                case final category?)
              category,
      ],
      city: city is String && city.trim().isNotEmpty ? city.trim() : null,
    );
  }
}
