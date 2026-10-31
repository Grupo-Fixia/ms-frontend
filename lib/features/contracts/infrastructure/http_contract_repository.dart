import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/service_category.dart';
import '../../../core/http/authorized_http.dart';
import '../application/ports/contract_repository.dart';
import '../domain/contract_exceptions.dart';
import '../domain/service_contract.dart';

/// Contrataciones contra ms-services (GC-361, API de GC-359).
///
/// Contrato (`docs/openapi.yaml` de ms-services):
/// - Cliente (`ROLE_CLIENT`): `GET /api/services/requests/{id}/contract`.
///   `404` si la solicitud no es suya o todavía no está contratada.
/// - Prestador (`ROLE_PROFESSIONAL`): `GET /api/services/contracts` y
///   `GET /api/services/contracts/{id}` (`404` si no es suya).
/// - El monto viaja como número con hasta dos decimales.
class HttpContractRepository implements ContractRepository {
  HttpContractRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _contracts = baseUrl.resolve(contractsPath),
        _requests = baseUrl.resolve(requestsPath),
        _http = authorizedHttp;

  static const contractsPath = '/api/services/contracts';
  static const requestsPath = '/api/services/requests';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'No tienes acceso a esta contratación.';
  static const notFoundMessage =
      'Esta solicitud aún no tiene una contratación.';
  static const unexpectedErrorMessage =
      'No pudimos consultar la contratación. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _contracts;
  final Uri _requests;
  final AuthorizedHttp _http;

  @override
  Future<ServiceContract> getForRequest(String serviceRequestId) => _one(
        _requests.replace(
          pathSegments: [
            ..._requests.pathSegments,
            serviceRequestId,
            'contract',
          ],
        ),
      );

  @override
  Future<ServiceContract> getMine(String id) => _one(
        _contracts.replace(pathSegments: [..._contracts.pathSegments, id]),
      );

  @override
  Future<List<ServiceContract>> listMine() async {
    final response = await _get(_contracts);
    final json = _decode(response);
    if (json is! List) throw const ContractFailure(unexpectedErrorMessage);
    return List.unmodifiable(json.map(_parse).whereType<ServiceContract>());
  }

  Future<ServiceContract> _one(Uri uri) async {
    final contract = _parse(_decode(await _get(uri)));
    if (contract == null) throw const ContractFailure(unexpectedErrorMessage);
    return contract;
  }

  Future<http.Response> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await _http.send(
        (headers) => _client.get(uri, headers: headers),
      );
    } on SessionExpiredException {
      throw const ContractFailure(
        sessionExpiredMessage,
        isSessionExpired: true,
      );
    } on BackendUnreachableException {
      throw const ContractFailure(connectionErrorMessage);
    }
    switch (response.statusCode) {
      case 200:
        return response;
      case 403:
        throw const ContractFailure(forbiddenMessage);
      case 404:
        throw const ContractFailure(notFoundMessage, isNotFound: true);
      default:
        throw const ContractFailure(unexpectedErrorMessage);
    }
  }

  /// `null` si faltan datos esenciales.
  ServiceContract? _parse(Object? json) {
    if (json is! Map) return null;
    final request = json['serviceRequest'];
    final location = request is Map ? request['approximateLocation'] : null;
    final exact = request is Map ? request['exactLocation'] : null;
    final category = request is Map
        ? ServiceCategory.fromApi(_string(request['category']))
        : null;
    final amount = json['amount'];
    final agreedAt = _date(json['agreedAt']);
    final contractedAt = _date(json['contractedAt']);
    final ids = [
      json['id'],
      json['serviceRequestId'],
      json['quotationId'],
      json['clientId'],
      json['providerId'],
    ];
    if (ids.any((id) => id is! String || id.isEmpty) ||
        amount is! num ||
        agreedAt == null ||
        contractedAt == null ||
        request is! Map ||
        category == null) {
      return null;
    }
    final address = exact is Map ? _string(exact['address']) : null;
    return ServiceContract(
      id: ids[0] as String,
      serviceRequestId: ids[1] as String,
      quotationId: ids[2] as String,
      clientId: ids[3] as String,
      providerId: ids[4] as String,
      amountInCents: (amount * 100).round(),
      currency: _string(json['currency']) ?? 'COP',
      scope: _string(json['scope']) ?? '',
      conditions: _string(json['conditions']) ?? '',
      agreedAt: agreedAt,
      contractedAt: contractedAt,
      request: ContractedRequest(
        category: category,
        description: _string(request['description']) ?? '',
        city: location is Map ? _string(location['city']) ?? '' : '',
        zone: location is Map ? _string(location['zone']) ?? '' : '',
        exactAddress:
            address == null || address.trim().isEmpty ? null : address.trim(),
        expectedAt: _date(request['expectedAt']),
      ),
      serviceStatus: ServiceRequestStatus.fromApi(
          _string(json['serviceStatus']) ?? _string(request['status'])),
      timeline: _timeline(json['timeline']),
    );
  }

  /// Se descartan los cambios que el frontend no entiende, sin inventar
  /// ninguno.
  List<ContractTransition> _timeline(Object? json) {
    if (json is! List) return const [];
    final transitions = <ContractTransition>[];
    for (final item in json) {
      if (item is! Map) continue;
      final to = ServiceRequestStatus.fromApi(_string(item['toStatus']));
      final at = _date(item['occurredAt']);
      if (to == null || at == null) continue;
      final reason = _string(item['reason'])?.trim();
      transitions.add(ContractTransition(
        fromStatus: ServiceRequestStatus.fromApi(_string(item['fromStatus'])),
        toStatus: to,
        actor: TransitionActor.fromApi(_string(item['actorRole'])),
        reason: reason == null || reason.isEmpty ? null : reason,
        occurredAt: at,
      ));
    }
    return List.unmodifiable(transitions);
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
