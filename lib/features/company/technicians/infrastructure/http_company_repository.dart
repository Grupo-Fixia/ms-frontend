import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/service_category.dart';
import '../../../../core/http/authorized_http.dart';
import '../application/ports/company_repository.dart';
import '../domain/associated_technician.dart';
import '../domain/company_account.dart';
import '../domain/company_exceptions.dart';

/// Empresa del administrador autenticado contra ms-users (GC-467, API de
/// GC-466).
///
/// Contrato (`docs/openapi.yaml` de ms-users):
/// - `GET /api/users/companies/me` → `200 {id, name, nit}`.
/// - `GET /api/users/companies/me/technicians` → `200 {technicians: [{userId,
///   displayName, verificationStatus, categories, professionalDescription,
///   yearsOfExperience, city}]}`; lista vacía si no tiene técnicos.
/// - `403` el rol no es `COMPANY`; `404` la cuenta no administra ninguna
///   empresa. La empresa sale del token: las rutas no reciben su id.
class HttpCompanyRepository implements CompanyRepository {
  HttpCompanyRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _companyEndpoint = baseUrl.resolve(companyPath),
        _techniciansEndpoint = baseUrl.resolve(techniciansPath),
        _http = authorizedHttp;

  static const companyPath = '/api/users/companies/me';
  static const techniciansPath = '/api/users/companies/me/technicians';

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const forbiddenMessage = 'Esta sección es solo para empresas.';
  static const notFoundMessage =
      'Tu cuenta no administra ninguna empresa. Escríbenos a soporte.';
  static const unexpectedErrorMessage =
      'No pudimos completar la acción. Inténtalo más tarde.';

  final http.Client _client;
  final Uri _companyEndpoint;
  final Uri _techniciansEndpoint;
  final AuthorizedHttp _http;

  @override
  Future<CompanyAccount> getMine() async {
    final response = await _send(
      (headers) => _client.get(_companyEndpoint, headers: headers),
    );
    _throwOnError(response);
    final json = _decode(response);
    final id = json is Map ? json['id'] : null;
    final name = json is Map ? json['name'] : null;
    if (id is! String || name is! String || name.trim().isEmpty) {
      throw const CompanyFailure(unexpectedErrorMessage);
    }
    final nit = json is Map ? json['nit'] : null;
    return CompanyAccount(
      id: id,
      name: name.trim(),
      nit: nit is String && nit.trim().isNotEmpty ? nit.trim() : null,
    );
  }

  @override
  Future<List<AssociatedTechnician>> listTechnicians() async {
    final response = await _send(
      (headers) => _client.get(_techniciansEndpoint, headers: headers),
    );
    _throwOnError(response);
    final json = _decode(response);
    final technicians = json is Map ? json['technicians'] : null;
    if (technicians is! List) {
      throw const CompanyFailure(unexpectedErrorMessage);
    }
    return List.unmodifiable(
      technicians.map(_parseTechnician).whereType<AssociatedTechnician>(),
    );
  }

  /// Un elemento sin `userId` se descarta: sin él no se puede proponer al
  /// técnico en una postulación.
  AssociatedTechnician? _parseTechnician(Object? item) {
    if (item is! Map) return null;
    final userId = item['userId'];
    if (userId is! String || userId.isEmpty) return null;
    final categories = item['categories'];
    final years = item['yearsOfExperience'];
    return AssociatedTechnician(
      userId: userId,
      displayName: _text(item['displayName']),
      verificationStatus:
          VerificationStatus.fromApi(_text(item['verificationStatus'])),
      categories: categories is List
          ? List.unmodifiable(
              categories
                  .whereType<String>()
                  .map(ServiceCategory.fromApi)
                  .whereType<ServiceCategory>(),
            )
          : const [],
      professionalDescription: _text(item['professionalDescription']),
      yearsOfExperience: years is int ? years : null,
      city: _text(item['city']),
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const CompanyFailure(sessionExpiredMessage, isSessionExpired: true);
    } on BackendUnreachableException {
      throw const CompanyFailure(connectionErrorMessage);
    }
  }

  void _throwOnError(http.Response response) {
    switch (response.statusCode) {
      case 200:
        return;
      case 403:
        throw const CompanyFailure(forbiddenMessage);
      case 404:
        throw const CompanyFailure(notFoundMessage);
      default:
        throw const CompanyFailure(unexpectedErrorMessage);
    }
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
