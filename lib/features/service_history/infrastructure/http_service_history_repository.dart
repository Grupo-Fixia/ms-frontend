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
///
/// Registrar (GC-445, `docs/contracts/evaluaciones.md` §4.1 de ms-users):
/// - `POST /api/users/evaluations {serviceRequestId, rating, comment}` →
///   `201` creada o `200` si es un reintento idéntico, con la evaluación.
/// - `400` datos inválidos; `403` rol no permitido; `404` el servicio no
///   existe o quien llama no participó; `409` ya existe otra evaluación suya;
///   `422 {reasons}` no evaluable; `503` no se pudo verificar el cierre.
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
  static const invalidSubmissionMessage =
      'Revisa la calificación: va de 1 a 5 estrellas y el comentario admite '
      'hasta 500 caracteres.';
  static const forbiddenSubmissionMessage =
      'Solo clientes y técnicos pueden calificar servicios.';
  static const notFoundSubmissionMessage =
      'No encontramos este servicio entre los tuyos.';
  static const alreadyEvaluatedMessage =
      'Ya habías calificado este servicio. Te mostramos tu evaluación.';
  static const notAllowedMessage = 'Este servicio no se puede calificar.';
  static const verificationUnavailableMessage =
      'No pudimos verificar el cierre del servicio en este momento. '
      'Inténtalo de nuevo en unos minutos.';
  static const unconfirmedSubmissionMessage =
      'No pudimos confirmar tu calificación. Vuelve a consultar el servicio '
      'antes de intentarlo otra vez.';

  /// Motivos de `422` que define el contrato de ms-users.
  static const rejectionMessages = {
    'SERVICE_NOT_CLOSED':
        'Solo se puede calificar cuando el cliente confirma el cierre del '
            'servicio.',
    'COMPANY_SERVICE_NOT_EVALUABLE':
        'Los servicios prestados por una empresa no se califican.',
    'EVALUATION_WINDOW_EXPIRED':
        'Ya pasó el plazo para calificar este servicio.',
    'EVALUATED_USER_NOT_FOUND':
        'La cuenta de tu contraparte ya no existe, así que no se puede '
            'calificar.',
  };

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

  @override
  Future<ServiceEvaluation> submit(NewServiceEvaluation evaluation) async {
    final body = jsonEncode({
      'serviceRequestId': evaluation.serviceRequestId,
      'rating': evaluation.rating,
      if (evaluation.comment != null) 'comment': evaluation.comment,
    });
    final response = await _send(
      _http,
      (headers) => _client.post(
        _endpoint,
        headers: {
          ...headers,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: body,
      ),
    );
    final json = _decode(response);
    switch (response.statusCode) {
      case 200:
      case 201:
        final saved = _parseEvaluation(json);
        // Solo se acepta la confirmación de lo que se envió.
        if (saved == null ||
            saved.serviceRequestId != evaluation.serviceRequestId ||
            saved.rating != evaluation.rating) {
          throw const ServiceHistoryFailure(unconfirmedSubmissionMessage);
        }
        return saved;
      case 400:
        throw const ServiceHistoryFailure(invalidSubmissionMessage);
      case 403:
        throw const ServiceHistoryFailure(forbiddenSubmissionMessage);
      case 404:
        throw const ServiceHistoryFailure(notFoundSubmissionMessage,
            notAllowed: true);
      case 409:
        throw const ServiceHistoryFailure(alreadyEvaluatedMessage,
            alreadyEvaluated: true);
      case 422:
        final reasons = json is Map ? json['reasons'] : null;
        final known = reasons is List
            ? reasons
                .whereType<String>()
                .map((r) => rejectionMessages[r])
                .whereType<String>()
                .toList()
            : <String>[];
        throw ServiceHistoryFailure(
            known.isEmpty ? notAllowedMessage : known.join(' '),
            notAllowed: true);
      case 503:
        throw const ServiceHistoryFailure(verificationUnavailableMessage);
      default:
        throw const ServiceHistoryFailure(unconfirmedSubmissionMessage);
    }
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
