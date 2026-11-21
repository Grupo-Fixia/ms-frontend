import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/http/authorized_http.dart';
import '../domain/company_invitation.dart';

/// `ms-users` (GC-523), con el token de la cuenta de empresa:
/// - `POST /api/users/companies/me/invitations` `{technicianEmail}` → 201
/// - `GET /api/users/companies/me/invitations?status=` → `{invitations: [...]}`
/// - `DELETE /api/users/companies/me/invitations/{id}` → 204
class HttpCompanyInvitationsRepository implements CompanyInvitationsGateway {
  HttpCompanyInvitationsRepository({
    required http.Client client,
    required Uri baseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _base = baseUrl.resolve('/api/users/companies/me/invitations'),
        _http = authorizedHttp;

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const unavailableMessage =
      'Las invitaciones no están disponibles en este momento. '
      'Inténtalo más tarde.';

  /// 422: el mismo mensaje para los tres casos, sin revelar cuál (D3).
  static const notInvitableMessage =
      'No es posible invitar a ese correo. Debe ser de un técnico activo de '
      'Fixia que no pertenezca a ninguna empresa.';
  static const alreadyPendingMessage =
      'Ya le enviaste una invitación pendiente a ese técnico.';
  static const notPendingMessage =
      'Esta invitación ya no está pendiente: actualiza la lista.';
  static const notFoundMessage = 'No encontramos esa invitación.';
  static const forbiddenMessage = 'Esta cuenta no es de una empresa.';

  final http.Client _client;
  final Uri _base;
  final AuthorizedHttp _http;

  @override
  Future<CompanyInvitation> invite(String technicianEmail) async {
    final error = validateTechnicianEmail(technicianEmail);
    if (error != null) throw InvitationFailure(error, statusCode: 400);
    final response = await _send((headers) => _client.post(
          _base,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'technicianEmail': technicianEmail.trim()}),
        ));
    if (response.statusCode == 409) {
      throw const InvitationFailure(alreadyPendingMessage, statusCode: 409);
    }
    _check(response);
    final json = _decode(response);
    if (json is! Map<String, dynamic>) {
      throw const InvitationFailure(unavailableMessage);
    }
    try {
      return CompanyInvitation.fromJson(json);
    } on FormatException {
      throw const InvitationFailure(unavailableMessage);
    }
  }

  @override
  Future<List<CompanyInvitation>> list({InvitationStatus? status}) async {
    final uri = status == null
        ? _base
        : _base.replace(queryParameters: {'status': status.api});
    final response = await _send((h) => _client.get(uri, headers: h));
    _check(response);
    final json = _decode(response);
    final items = json is Map ? json['invitations'] : null;
    if (items is! List) throw const InvitationFailure(unavailableMessage);
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          if (_parse(item) case final invitation?) invitation,
    ];
  }

  @override
  Future<void> cancel(String invitationId) async {
    final uri =
        _base.replace(pathSegments: [..._base.pathSegments, invitationId]);
    final response = await _send((h) => _client.delete(uri, headers: h));
    if (response.statusCode == 409) {
      throw const InvitationFailure(notPendingMessage, statusCode: 409);
    }
    _check(response);
  }

  static CompanyInvitation? _parse(Map<String, dynamic> json) {
    try {
      return CompanyInvitation.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const InvitationFailure(sessionExpiredMessage,
          isSessionExpired: true);
    } on BackendUnreachableException {
      throw const InvitationFailure(connectionErrorMessage);
    }
  }

  void _check(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    final message = switch (status) {
      422 => notInvitableMessage,
      404 => notFoundMessage,
      403 => forbiddenMessage,
      400 => _detail(response) ?? 'Revisa el correo del técnico.',
      _ => unavailableMessage,
    };
    throw InvitationFailure(message, statusCode: status);
  }

  String? _detail(http.Response response) {
    final body = _decode(response);
    final detail = body is Map ? body['detail'] : null;
    return detail is String && detail.trim().isNotEmpty ? detail.trim() : null;
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
