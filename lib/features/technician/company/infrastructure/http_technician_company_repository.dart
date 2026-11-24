import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/http/authorized_http.dart';
import '../domain/technician_company.dart';

/// `ms-users` (GC-524), con el token del técnico:
/// - `GET /api/users/technicians/me/invitations`
/// - `POST /api/users/technicians/me/invitations/{id}/accept` y `/reject`
/// - `GET` y `DELETE /api/users/technicians/me/company`
class HttpTechnicianCompanyRepository implements TechnicianCompanyGateway {
  HttpTechnicianCompanyRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _base = baseUrl.resolve('/api/users/technicians/me/'),
        _http = authorizedHttp;

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const unavailableMessage =
      'Esta sección no está disponible en este momento. Inténtalo más tarde.';
  static const notPendingMessage =
      'Esta invitación ya no está pendiente o venció.';
  static const alreadyInCompanyMessage = 'Ya perteneces a una empresa.';
  static const companyUnavailableMessage =
      'La empresa que te invitó ya no está activa.';
  static const notFoundMessage = 'No encontramos esa invitación.';
  static const forbiddenMessage = 'Esta cuenta no es de un técnico.';
  static const notMemberMessage = 'Ya no perteneces a ninguna empresa.';
  static const cannotLeaveMessage =
      'Todavía no puedes desvincularte de la empresa.';
  static const leaveUnverifiedMessage =
      'No pudimos verificar tus trabajos y pagos pendientes. '
      'Inténtalo más tarde.';

  final http.Client _client;
  final Uri _base;
  final AuthorizedHttp _http;

  Uri _at(List<String> segments) => _base.replace(pathSegments: [
        ..._base.pathSegments.where((s) => s.isNotEmpty),
        ...segments,
      ]);

  @override
  Future<List<ReceivedInvitation>> invitations() async {
    final response =
        await _send((h) => _client.get(_at(['invitations']), headers: h));
    _check(response);
    final json = _decode(response);
    final items = json is Map ? json['invitations'] : json;
    if (items is! List) {
      throw const TechnicianCompanyFailure(unavailableMessage);
    }
    final result = <ReceivedInvitation>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      try {
        result.add(ReceivedInvitation.fromJson(item));
      } on FormatException {
        // Se omite la que no se puede mostrar.
      }
    }
    return result;
  }

  @override
  Future<Membership> accept(String invitationId) async {
    final response = await _send((h) =>
        _client.post(_at(['invitations', invitationId, 'accept']), headers: h));
    _check(response);
    return _membership(_decode(response));
  }

  @override
  Future<void> reject(String invitationId) async {
    final response = await _send((h) =>
        _client.post(_at(['invitations', invitationId, 'reject']), headers: h));
    _check(response);
  }

  @override
  Future<Membership?> membership() async {
    final response =
        await _send((h) => _client.get(_at(['company']), headers: h));
    // 404: es independiente.
    if (response.statusCode == 404) return null;
    _check(response);
    return _membership(_decode(response));
  }

  @override
  Future<void> leave() async {
    final response =
        await _send((h) => _client.delete(_at(['company']), headers: h));
    final status = response.statusCode;
    if (status == 409) {
      final body = _decode(response);
      final reasons = body is Map ? body['reasons'] : null;
      final ids = body is Map ? body['serviceRequestIds'] : null;
      throw TechnicianCompanyFailure(
        cannotLeaveMessage,
        statusCode: 409,
        blockers: [
          if (reasons is List)
            for (final r in reasons)
              if (LeaveBlocker.fromApi(r) case final blocker?) blocker,
        ],
        serviceRequestIds: [
          if (ids is List) ...ids.whereType<String>(),
        ],
      );
    }
    if (status == 503) {
      throw const TechnicianCompanyFailure(leaveUnverifiedMessage,
          statusCode: 503);
    }
    if (status == 404) {
      throw const TechnicianCompanyFailure(notMemberMessage, statusCode: 404);
    }
    _check(response);
  }

  Membership _membership(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const TechnicianCompanyFailure(unavailableMessage);
    }
    try {
      return Membership.fromJson(json);
    } on FormatException {
      throw const TechnicianCompanyFailure(unavailableMessage);
    }
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const TechnicianCompanyFailure(sessionExpiredMessage,
          isSessionExpired: true);
    } on BackendUnreachableException {
      throw const TechnicianCompanyFailure(connectionErrorMessage);
    }
  }

  void _check(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    if (status == 409) {
      final body = _decode(response);
      final reasons = body is Map ? body['reasons'] : null;
      final list = reasons is List ? reasons : const [];
      final message = list.contains('ALREADY_IN_COMPANY')
          ? alreadyInCompanyMessage
          : list.contains('COMPANY_UNAVAILABLE')
              ? companyUnavailableMessage
              : notPendingMessage;
      throw TechnicianCompanyFailure(message, statusCode: 409);
    }
    final message = switch (status) {
      404 => notFoundMessage,
      403 => forbiddenMessage,
      _ => unavailableMessage,
    };
    throw TechnicianCompanyFailure(message, statusCode: status);
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
