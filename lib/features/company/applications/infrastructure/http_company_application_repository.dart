import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/http/authorized_http.dart';
import '../../../technician/applications/domain/application_exceptions.dart';
import '../../../technician/applications/domain/service_application.dart';
import '../../../technician/applications/infrastructure/application_json.dart';
import '../../../technician/applications/infrastructure/http_application_repository.dart';
import '../application/company_repositories.dart';
import '../domain/company_application_failure.dart';

class HttpCompanyApplicationRepository implements CompanyApplicationRepository {
  HttpCompanyApplicationRepository(
      {required http.Client client,
      required Uri baseUrl,
      required AuthorizedHttp authorizedHttp})
      : _client = client,
        _url = baseUrl.resolve(HttpApplicationRepository.path),
        _http = authorizedHttp,
        _reads = HttpApplicationRepository(
            client: client, baseUrl: baseUrl, authorizedHttp: authorizedHttp);
  final http.Client _client;
  final Uri _url;
  final AuthorizedHttp _http;
  final HttpApplicationRepository _reads;

  @override
  Future<ServiceApplication> applyCompany(String requestId,
      {required String technicianUserId, required ProposedPrice price}) async {
    if (requestId.trim().isEmpty ||
        technicianUserId.trim().isEmpty ||
        validateCompanyPrice(price.amount) != null) {
      throw const ApplicationFailure(
          'Selecciona una solicitud, un técnico asociado y un precio válido.');
    }
    final independent = encodeApplicationJson(
        serviceRequestId: requestId,
        amount: price.amount,
        currency: ProposedPrice.currency);
    final body =
        '${independent.substring(0, independent.length - 1)},"technicianId":${jsonEncode(technicianUserId)}}';
    final http.Response response;
    try {
      response = await _http.send((headers) => _client.post(_url,
          headers: {
            ...headers,
            'Content-Type': 'application/json; charset=utf-8'
          },
          body: body));
    } on SessionExpiredException {
      throw const ApplicationFailure(
          HttpApplicationRepository.sessionExpiredMessage,
          isSessionExpired: true);
    } on BackendUnreachableException {
      throw const CompanySubmissionUnconfirmed();
    }
    Object? json;
    try {
      json = decodeApplicationJson(utf8.decode(response.bodyBytes));
    } on FormatException {
      json = null;
    }
    final map = json is Map ? json : const {};
    if (response.statusCode != 201) {
      switch (response.statusCode) {
        case 400:
          final errors = <String, String>{};
          if (map['errors'] is List) {
            for (final item in map['errors'] as List) {
              if (item is Map &&
                  item['field'] is String &&
                  item['message'] is String) {
                errors.putIfAbsent(
                    item['field'] as String, () => item['message'] as String);
              }
            }
          }
          throw ApplicationFailure(HttpApplicationRepository.invalidDataMessage,
              fieldErrors: errors);
        case 403:
          throw const ApplicationFailure(
              HttpApplicationRepository.forbiddenMessage);
        case 404:
          throw const ApplicationFailure(
              HttpApplicationRepository.notFoundMessage);
        case 409:
          throw CompanyApplicationConflict(
              id: map['applicationId'] is String
                  ? map['applicationId'] as String
                  : null);
        case 422:
          final reasons = map['reasons'];
          const messages = {
            'TECHNICIAN_NOT_ASSOCIATED':
                'El técnico seleccionado ya no está asociado a tu empresa.',
            'TECHNICIAN_NOT_FOUND': 'No se encontró el técnico seleccionado.',
            'CATEGORY':
                'El técnico seleccionado no ofrece la especialidad requerida.',
            'ZONE':
                'La solicitud está fuera de la cobertura del técnico seleccionado.',
            'AVAILABILITY':
                'El técnico seleccionado no está disponible para esa fecha.',
            'VERIFICATION': 'El técnico seleccionado no está verificado.',
          };
          final known = reasons is List
              ? reasons
                  .whereType<String>()
                  .map((r) => messages[r])
                  .whereType<String>()
                  .toList()
              : <String>[];
          throw ApplicationFailure(known.isEmpty
              ? 'El técnico seleccionado no es elegible para esta solicitud.'
              : known.join(' '));
        case 503:
          throw const ApplicationFailure(
              HttpApplicationRepository.eligibilityUnavailableMessage);
        default:
          throw const CompanySubmissionUnconfirmed();
      }
    }
    final amount = map['proposedAmount'];
    final summary = map['serviceRequest'];
    final id = map['id'];
    if (id is! String ||
        id.isEmpty ||
        map['status'] != 'APPLIED' ||
        map['providerType'] != 'COMPANY' ||
        map['technicianId'] != technicianUserId ||
        map['currency'] != 'COP' ||
        amount is! JsonApplicationAmount ||
        ProposedPrice.tryParse(amount.lexeme)?.amount != price.amount ||
        summary is! Map ||
        summary['id'] != requestId) throw const CompanySubmissionUnconfirmed();
    try {
      final saved = await getMine(id);
      if (saved.id != id ||
          saved.serviceRequest.id != requestId ||
          saved.technicianId != technicianUserId ||
          saved.proposedPrice?.amount != price.amount) {
        throw const CompanySubmissionUnconfirmed();
      }
      return saved;
    } on ApplicationFailure catch (failure) {
      if (failure.isSessionExpired) rethrow;
      throw const CompanySubmissionUnconfirmed();
    }
  }

  ServiceApplication _company(ServiceApplication item) {
    if (item.providerType != ApplicationProviderType.company ||
        item.technicianId == null ||
        (item.proposedPrice != null &&
            validateCompanyPrice(item.proposedPrice!.amount) != null)) {
      throw const ApplicationFailure(
          'La respuesta no corresponde a una postulación empresarial.');
    }
    return item;
  }

  @override
  Future<ServiceApplication> getMine(String id) async {
    final saved = _company(await _reads.getMine(id));
    if (saved.id != id) {
      throw const ApplicationFailure(
          'La postulación consultada no coincide con la respuesta.');
    }
    return saved;
  }

  @override
  Future<List<ServiceApplication>> listMine() async {
    final items = (await _reads.listMine()).map(_company).toList();
    if (items.map((item) => item.id).toSet().length != items.length) {
      throw const ApplicationFailure(
          'La consulta contiene postulaciones duplicadas.');
    }
    return List.unmodifiable(items);
  }
}
