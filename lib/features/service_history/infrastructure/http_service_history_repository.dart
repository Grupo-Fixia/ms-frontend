import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/service_category.dart';
import '../../../core/domain/service_budget.dart';
import '../../../core/http/authorized_http.dart';
import '../application/ports/service_history_repository.dart';
import '../domain/service_evaluation.dart';
import '../domain/service_history_entry.dart';
import '../domain/service_history_exceptions.dart';

const _connectionErrorMessage =
    'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
const _sessionExpiredMessage = 'Tu sesión expiró. Inicia sesión de nuevo.';
const _unexpectedErrorMessage =
    'No pudimos cargar tu historial. Inténtalo más tarde.';

/// Historial propio contra ms-services (GC-449, API de GC-448).
///
/// Contrato (`docs/openapi.yaml` de ms-services):
/// - `GET /api/services/history?limit=&cursor=` → `200 {items, nextCursor}`,
///   del más reciente al más antiguo; página vacía si no hay servicios.
/// - `400` límite o cursor inválidos; `403` el rol no es cliente ni técnico.
class HttpServiceHistoryRepository implements ServiceHistoryRepository {
  HttpServiceHistoryRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _endpoint = baseUrl.resolve(path),
        _http = authorizedHttp;

  static const path = '/api/services/history';

  static const connectionErrorMessage = _connectionErrorMessage;
  static const sessionExpiredMessage = _sessionExpiredMessage;
  static const forbiddenMessage =
      'El historial está disponible para clientes y técnicos.';
  static const unexpectedErrorMessage = _unexpectedErrorMessage;

  final http.Client _client;
  final Uri _endpoint;
  final AuthorizedHttp _http;

  @override
  Future<ServiceHistoryResult> listPage(
      {String? cursor, int limit = 20}) async {
    final uri = _endpoint.replace(queryParameters: {
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
    final response = await _send(
      _http,
      (headers) => _client.get(uri, headers: headers),
    );
    switch (response.statusCode) {
      case 200:
        break;
      case 403:
        throw const ServiceHistoryFailure(forbiddenMessage);
      default:
        throw const ServiceHistoryFailure(unexpectedErrorMessage);
    }
    final json = _decode(response);
    final items = json is Map ? json['items'] : null;
    if (items is! List) {
      throw const ServiceHistoryFailure(unexpectedErrorMessage);
    }
    final nextCursor = json is Map ? json['nextCursor'] : null;
    return ServiceHistoryResult(
      items: List.unmodifiable(
          items.map(_parseEntry).whereType<ServiceHistoryEntry>()),
      nextCursor:
          nextCursor is String && nextCursor.isNotEmpty ? nextCursor : null,
    );
  }

  /// Un elemento sin los datos mínimos (ids, rol, importe o fechas de la
  /// contratación) se descarta en vez de mostrarse incompleto.
  ServiceHistoryEntry? _parseEntry(Object? item) {
    if (item is! Map) return null;
    final serviceRequestId = item['serviceRequestId'];
    final contractId = item['contractId'];
    final counterpartId = item['counterpartId'];
    final role = HistoryRole.fromApi(_text(item['role']));
    final agreedAt = _date(item['agreedAt']);
    final contractedAt = _date(item['contractedAt']);
    final ServiceBudget? amount;
    final ServiceBudget? budget;
    try {
      amount =
          ServiceBudget.fromJson(item['contractedAmount'], item['currency']);
      budget = item['budgetAmount'] == null
          ? null
          : ServiceBudget.fromJson(item['budgetAmount'], item['currency']);
    } on FormatException {
      return null;
    }
    if (serviceRequestId is! String ||
        contractId is! String ||
        counterpartId is! String ||
        role == null ||
        amount == null ||
        agreedAt == null ||
        contractedAt == null) {
      return null;
    }
    return ServiceHistoryEntry(
      serviceRequestId: serviceRequestId,
      contractId: contractId,
      role: role,
      counterpartId: counterpartId,
      category: ServiceCategory.fromApi(_text(item['category']) ?? ''),
      status: ServiceRequestStatus.fromApi(_text(item['status'])),
      contractedAmount: amount,
      budget: budget,
      agreedAt: agreedAt,
      contractedAt: contractedAt,
      startedAt: _date(item['startedAt']),
      finishedAt: _date(item['finishedAt']),
      closedAt: _date(item['closedAt']),
      lastTransitionAt: _date(item['lastTransitionAt']),
    );
  }
}

/// Evaluaciones de varios servicios contra ms-users (GC-449, API de GC-444).
///
/// Contrato (`docs/openapi.yaml` de ms-users):
/// - `GET /api/users/evaluations?serviceRequestIds=a,b` (de 1 a 50 ids) →
///   `200 {items: [{serviceRequestId, direction, evaluatorId, evaluatedId,
///   rating, comment, createdAt}]}`; solo las de servicios en que quien
///   consulta evaluó o fue evaluado.
/// - `400` sin ids, más de 50 o mal formados; `403` rol no permitido.
class HttpServiceEvaluationRepository implements ServiceEvaluationRepository {
  HttpServiceEvaluationRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _endpoint = baseUrl.resolve(path),
        _http = authorizedHttp;

  static const path = '/api/users/evaluations';

  static const unexpectedErrorMessage =
      'No pudimos cargar las evaluaciones. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _endpoint;
  final AuthorizedHttp _http;

  @override
  Future<List<ServiceEvaluation>> listFor(
      List<String> serviceRequestIds) async {
    if (serviceRequestIds.isEmpty) return const [];
    final uri = _endpoint.replace(
        queryParameters: {'serviceRequestIds': serviceRequestIds.join(',')});
    final response = await _send(
      _http,
      (headers) => _client.get(uri, headers: headers),
    );
    if (response.statusCode != 200) {
      throw const ServiceHistoryFailure(unexpectedErrorMessage);
    }
    final json = _decode(response);
    final items = json is Map ? json['items'] : null;
    if (items is! List) {
      throw const ServiceHistoryFailure(unexpectedErrorMessage);
    }
    return List.unmodifiable(
        items.map(_parseEvaluation).whereType<ServiceEvaluation>());
  }

  ServiceEvaluation? _parseEvaluation(Object? item) {
    if (item is! Map) return null;
    final serviceRequestId = item['serviceRequestId'];
    final direction = EvaluationDirection.fromApi(_text(item['direction']));
    final evaluatorId = item['evaluatorId'];
    final evaluatedId = item['evaluatedId'];
    final rating = item['rating'];
    if (serviceRequestId is! String ||
        direction == null ||
        evaluatorId is! String ||
        evaluatedId is! String ||
        rating is! int ||
        rating < 1 ||
        rating > 5) {
      return null;
    }
    return ServiceEvaluation(
      serviceRequestId: serviceRequestId,
      direction: direction,
      evaluatorId: evaluatorId,
      evaluatedId: evaluatedId,
      rating: rating,
      comment: _text(item['comment']),
      createdAt: _date(item['createdAt']),
    );
  }
}

Future<http.Response> _send(
  AuthorizedHttp authorizedHttp,
  Future<http.Response> Function(Map<String, String> headers) request,
) async {
  try {
    return await authorizedHttp.send(request);
  } on SessionExpiredException {
    throw const ServiceHistoryFailure(_sessionExpiredMessage,
        isSessionExpired: true);
  } on BackendUnreachableException {
    throw const ServiceHistoryFailure(_connectionErrorMessage);
  }
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// Siempre UTF-8, para que las tildes no lleguen dañadas (TD V1, DEF-02).
Object? _decode(http.Response response) {
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    return null;
  }
}
