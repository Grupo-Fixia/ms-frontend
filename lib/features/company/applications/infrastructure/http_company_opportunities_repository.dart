import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/http/authorized_http.dart';
import '../../../technician/opportunities/infrastructure/http_opportunity_repository.dart';
import '../../../technician/applications/domain/application_exceptions.dart';
import '../application/company_repositories.dart';
import '../domain/company_opportunity.dart';

class HttpCompanyOpportunitiesRepository
    implements CompanyOpportunitiesRepository {
  HttpCompanyOpportunitiesRepository(
      {required http.Client client,
      required Uri baseUrl,
      required AuthorizedHttp authorizedHttp})
      : _client = client,
        _http = authorizedHttp,
        _endpoint = baseUrl.resolve(HttpOpportunityRepository.path),
        _requests = HttpOpportunityRepository(
            client: client, baseUrl: baseUrl, authorizedHttp: authorizedHttp);
  final http.Client _client;
  final AuthorizedHttp _http;
  final Uri _endpoint;
  final HttpOpportunityRepository _requests;
  static const invalidResponse =
      'No pudimos verificar las oportunidades de tu empresa. Actualiza la lista.';

  @override
  Future<CompanyOpportunityPage> fetchPage(
      {required int limit, String? cursor}) async {
    if (limit < 1 || limit > 50 || (cursor != null && cursor.trim().isEmpty)) {
      throw const ApplicationFailure(
          HttpOpportunityRepository.invalidQueryMessage);
    }
    final http.Response response;
    try {
      response = await _http.send((headers) => _client.get(
          _endpoint.replace(queryParameters: {
            'limit': '$limit',
            if (cursor != null) 'cursor': cursor
          }),
          headers: headers));
    } on SessionExpiredException {
      throw const ApplicationFailure(
          HttpOpportunityRepository.sessionExpiredMessage,
          isSessionExpired: true);
    } on BackendUnreachableException {
      throw const ApplicationFailure(
          HttpOpportunityRepository.connectionErrorMessage);
    }
    switch (response.statusCode) {
      case 200:
        return _parse(response);
      case 400:
        throw const ApplicationFailure(
            HttpOpportunityRepository.invalidQueryMessage);
      case 403:
        throw const ApplicationFailure(
            'Se requiere una sesión empresarial para consultar estas oportunidades.');
      case 503:
        throw const ApplicationFailure(
            HttpOpportunityRepository.eligibilityUnavailableMessage);
      default:
        throw const ApplicationFailure(
            HttpOpportunityRepository.unexpectedErrorMessage);
    }
  }

  CompanyOpportunityPage _parse(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map ||
          json['items'] is! List ||
          (json['nextCursor'] != null &&
              (json['nextCursor'] is! String ||
                  (json['nextCursor'] as String).trim().isEmpty))) {
        throw const FormatException();
      }
      final raw = json['items'] as List;
      final parsed = _requests.parsePage(json);
      if (parsed.items.length != raw.length ||
          parsed.items.map((e) => e.id).toSet().length != raw.length) {
        throw const FormatException();
      }
      final items = <CompanyOpportunity>[];
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i] as Map;
        final eligible = item['eligibleTechnicianIds'];
        final budget = item['budgetAmount'];
        final currency = item['budgetCurrency'];
        if (eligible is! List ||
            eligible.isEmpty ||
            eligible.any((id) => id is! String || id.trim().isEmpty) ||
            eligible.toSet().length != eligible.length ||
            (budget != null &&
                (budget is! num ||
                    !budget.isFinite ||
                    budget <= 0 ||
                    currency != 'COP')) ||
            (budget == null && currency != null)) {
          throw const FormatException();
        }
        items.add(CompanyOpportunity(
            request: parsed.items[i],
            eligibleTechnicianIds: Set.unmodifiable(eligible.cast<String>()),
            budgetAmount: budget as num?));
      }
      return CompanyOpportunityPage(
          items: List.unmodifiable(items), nextCursor: parsed.nextCursor);
    } catch (_) {
      throw const ApplicationFailure(invalidResponse);
    }
  }
}
