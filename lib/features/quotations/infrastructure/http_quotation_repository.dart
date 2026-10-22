import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/http/authorized_http.dart';
import '../application/ports/quotation_repository.dart';
import '../domain/quotation.dart';
import '../domain/quotation_exceptions.dart';

/// Cotizaciones contra ms-services (GC-356, API de GC-354).
///
/// Contrato (`docs/openapi.yaml` de ms-services):
/// - Prestador (`ROLE_PROFESSIONAL`):
///   - `POST /api/services/quotations` → `201` (`SENT`). `409` "Cotización no
///     permitida" si no tiene una selección vigente o ya hay una aceptada.
///   - `GET /api/services/quotations[?serviceRequestId=]` y
///     `GET /api/services/quotations/{id}` (`404` si no es suya).
/// - Cliente (`ROLE_CLIENT`): `GET /api/services/requests/{id}/quotations`
///   (`404` si la solicitud no es suya), y para responderlas (GC-358/GC-361)
///   `POST /api/services/requests/{id}/quotations/{quotationId}/acceptance` o
///   `/rejection` → `200` con la cotización ya `ACCEPTED` o `REJECTED`
///   (idempotente). `409` si ya no se puede responder (no es del prestador
///   seleccionado, ya hay una aceptada, o no está vigente en `SENT`).
/// - `400` con `errors[{field, message}]` o, para reglas de negocio (fechas),
///   solo con `detail`.
class HttpQuotationRepository implements QuotationRepository {
  HttpQuotationRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _quotations = baseUrl.resolve(quotationsPath),
        _requests = baseUrl.resolve(requestsPath),
        _http = authorizedHttp;

  static const quotationsPath = '/api/services/quotations';
  static const requestsPath = '/api/services/requests';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'No tienes acceso a estas cotizaciones.';
  static const notFoundMessage = 'No encontramos esa cotización o solicitud.';
  static const invalidDataMessage = 'Revisa los datos marcados.';
  static const notAllowedMessage =
      'Ya no puedes cotizar esta solicitud: no eres el prestador seleccionado '
      'o ya tiene una cotización aceptada.';
  static const responseNotAllowedMessage =
      'Esta cotización ya no se puede responder: venció, fue reemplazada o '
      'la solicitud ya tiene una cotización aceptada.';
  static const unexpectedErrorMessage =
      'No pudimos completar la acción. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _quotations;
  final Uri _requests;
  final AuthorizedHttp _http;

  @override
  Future<Quotation> send(NewQuotation quotation) async {
    final cents = quotation.amountInCents;
    final body = jsonEncode({
      'serviceRequestId': quotation.serviceRequestId,
      'amount': cents == null ? null : _amount(cents),
      'currency': quotation.currency,
      'scope': quotation.scope,
      'conditions': quotation.conditions,
      'agreedAt': quotation.agreedAt?.toUtc().toIso8601String(),
      'validUntil': quotation.validUntil?.toUtc().toIso8601String(),
    });
    final response = await _send(
      (headers) => _client.post(
        _quotations,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: body,
      ),
    );
    _throwOnError(response, success: 201);
    return _require(_decode(response));
  }

  @override
  Future<List<Quotation>> listMine({String? serviceRequestId}) async {
    final uri = serviceRequestId == null
        ? _quotations
        : _quotations.replace(
            queryParameters: {'serviceRequestId': serviceRequestId},
          );
    return _list(uri);
  }

  @override
  Future<Quotation> getMine(String id) async {
    final response = await _send(
      (headers) => _client.get(
        _quotations.replace(
          pathSegments: [..._quotations.pathSegments, id],
        ),
        headers: headers,
      ),
    );
    _throwOnError(response);
    return _require(_decode(response));
  }

  @override
  Future<List<Quotation>> listForRequest(String serviceRequestId) => _list(
        _requests.replace(
          pathSegments: [
            ..._requests.pathSegments,
            serviceRequestId,
            'quotations',
          ],
        ),
      );

  @override
  Future<Quotation> accept(String serviceRequestId, String quotationId) =>
      _respond(serviceRequestId, quotationId, 'acceptance');

  @override
  Future<Quotation> reject(String serviceRequestId, String quotationId) =>
      _respond(serviceRequestId, quotationId, 'rejection');

  Future<Quotation> _respond(
    String serviceRequestId,
    String quotationId,
    String decision,
  ) async {
    final uri = _requests.replace(
      pathSegments: [
        ..._requests.pathSegments,
        serviceRequestId,
        'quotations',
        quotationId,
        decision,
      ],
    );
    final response = await _send(
      (headers) => _client.post(uri, headers: headers),
    );
    _throwOnError(response, conflictMessage: responseNotAllowedMessage);
    return _require(_decode(response));
  }

  Future<List<Quotation>> _list(Uri uri) async {
    final response = await _send(
      (headers) => _client.get(uri, headers: headers),
    );
    _throwOnError(response);
    final json = _decode(response);
    if (json is! List) {
      throw const QuotationFailure(unexpectedErrorMessage);
    }
    return List.unmodifiable(json.map(_parse).whereType<Quotation>());
  }

  /// Centavos → número con dos decimales como máximo (lo que espera el
  /// backend). 15000050 → 150000.5.
  num _amount(int cents) => cents % 100 == 0 ? cents ~/ 100 : cents / 100;

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const QuotationFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    } on BackendUnreachableException {
      throw const QuotationFailure(connectionErrorMessage);
    }
  }

  void _throwOnError(
    http.Response response, {
    int success = 200,
    String conflictMessage = notAllowedMessage,
  }) {
    if (response.statusCode == success) return;
    final body = _decode(response);
    switch (response.statusCode) {
      case 400:
        final fieldErrors = _fieldErrors(body);
        final detail = body is Map ? body['detail'] : null;
        throw QuotationFailure(
          fieldErrors.isEmpty && detail is String && detail.trim().isNotEmpty
              ? detail.trim()
              : invalidDataMessage,
          fieldErrors: fieldErrors,
        );
      case 403:
        throw const QuotationFailure(forbiddenMessage);
      case 404:
        throw const QuotationFailure(notFoundMessage);
      case 409:
        final detail = body is Map ? body['detail'] : null;
        throw QuotationFailure(
          detail is String && detail.trim().isNotEmpty
              ? detail.trim()
              : conflictMessage,
        );
      default:
        throw const QuotationFailure(unexpectedErrorMessage);
    }
  }

  Quotation _require(Object? json) {
    final quotation = _parse(json);
    if (quotation == null) {
      throw const QuotationFailure(unexpectedErrorMessage);
    }
    return quotation;
  }

  /// `null` si faltan datos esenciales o el estado es desconocido.
  Quotation? _parse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final requestId = json['serviceRequestId'];
    final providerId = json['providerId'];
    final amount = json['amount'];
    final status = QuotationStatus.fromApi(_string(json['status']));
    final agreedAt = _date(json['agreedAt']);
    final validUntil = _date(json['validUntil']);
    if (id is! String ||
        id.isEmpty ||
        requestId is! String ||
        providerId is! String ||
        amount is! num ||
        status == null ||
        agreedAt == null ||
        validUntil == null) {
      return null;
    }
    final statusName = json['statusName'];
    final currency = json['currency'];
    final expired = json['expired'];
    return Quotation(
      id: id,
      serviceRequestId: requestId,
      providerId: providerId,
      amountInCents: (amount * 100).round(),
      currency: currency is String ? currency : 'COP',
      scope: _string(json['scope']) ?? '',
      conditions: _string(json['conditions']) ?? '',
      agreedAt: agreedAt,
      validUntil: validUntil,
      status: status,
      statusName: statusName is String && statusName.trim().isNotEmpty
          ? statusName.trim()
          : status.label,
      isExpired: expired == true,
      respondedAt: _date(json['respondedAt']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
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
