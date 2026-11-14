import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/http/authorized_http.dart';
import '../../payments/domain/payments.dart';
import '../domain/admin.dart';

/// Rutas del ADMIN (contrato GC-534) con el token de la sesión:
/// - ms-users: `GET /api/users/admin/users`, `GET /api/users/admin/users/{id}`
///   y `GET /api/users/admin/audit-events`.
/// - ms-payments: `GET /api/payments/admin/payments`,
///   `GET /api/payments/admin/audit-events` y
///   `POST /api/payments/{id}/refund?reason=` con `Idempotency-Key`.
/// Errores en problem+json: se muestra su `detail` (o `title`).
class HttpAdminRepository implements AdminGateway {
  HttpAdminRepository({
    required http.Client client,
    required Uri usersBaseUrl,
    required Uri paymentsBaseUrl,
    required AuthorizedHttp authorizedHttp,
  })  : _client = client,
        _users = usersBaseUrl.resolve('/api/users/'),
        _payments = paymentsBaseUrl.resolve('/api/payments/'),
        _http = authorizedHttp;

  static const connectionErrorMessage =
      'No pudimos conectar con Fixia. Revisa tu conexión e inténtalo de nuevo.';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const unavailableMessage =
      'La administración no está disponible en este momento. '
      'Inténtalo más tarde.';
  static const forbiddenMessage =
      'Esta cuenta no tiene permisos de administrador.';
  static const notFoundMessage = 'No encontramos ese registro.';

  static const pageSize = 20;

  final http.Client _client;
  final Uri _users;
  final Uri _payments;
  final AuthorizedHttp _http;

  @override
  Future<AdminList<AdminUser>> users({
    AdminUserRole? role,
    AdminUserStatus? status,
    String? query,
    String? cursor,
  }) async {
    final json = await _getObject(_at(_users, [
      'admin',
      'users'
    ], {
      if (role != null) 'role': role.api,
      if (status != null) 'status': status.api,
      if (query != null) 'q': query,
      'limit': '$pageSize',
      if (cursor != null) 'cursor': cursor,
    }));
    return _page(json, _user);
  }

  @override
  Future<AdminUserDetail> user(String id) async {
    final json = await _getObject(_at(_users, ['admin', 'users', id]));
    final detail = _userDetail(json);
    if (detail == null || detail.id != id) {
      throw const AdminFailure(unavailableMessage);
    }
    return detail;
  }

  @override
  Future<AdminList<AdminPayment>> payments({
    HoldStatus? holdStatus,
    String? userId,
    String? cursor,
  }) async {
    final hold = holdStatus == null ? null : _holdApi(holdStatus);
    final json = await _getObject(_at(_payments, [
      'admin',
      'payments'
    ], {
      if (hold != null) 'holdStatus': hold,
      if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
      'limit': '$pageSize',
      if (cursor != null) 'cursor': cursor,
    }));
    return _page(json, _payment);
  }

  @override
  Future<ServicePayment> refund(
    String paymentId, {
    required String reason,
    required String idempotencyKey,
  }) async {
    final error = validateRefundReason(reason);
    if (error != null) throw AdminFailure(error, statusCode: 400);
    final response = await _send((headers) => _client.post(
          _at(_payments, [paymentId, 'refund'], {'reason': reason.trim()}),
          headers: {...headers, 'Idempotency-Key': idempotencyKey},
        ));
    _check(response);
    final json = _decode(response);
    if (json is! Map<String, dynamic>) {
      throw const AdminFailure(unavailableMessage);
    }
    try {
      final payment = ServicePayment.fromJson(json);
      if (payment.id != paymentId) throw const FormatException('Otro pago');
      return payment;
    } on FormatException {
      throw const AdminFailure(unavailableMessage);
    }
  }

  @override
  Future<AdminList<AdminAuditEvent>> auditEvents(
    AuditSource source, {
    String? cursor,
  }) async {
    final base = source == AuditSource.users ? _users : _payments;
    final json = await _getObject(_at(base, [
      'admin',
      'audit-events'
    ], {
      'limit': '$pageSize',
      if (cursor != null) 'cursor': cursor,
    }));
    return _page(json, _auditEvent);
  }

  // ---------------------------------------------------------------------------

  Uri _at(Uri base, List<String> segments, [Map<String, String>? query]) {
    final uri = base.replace(pathSegments: [
      ...base.pathSegments.where((s) => s.isNotEmpty),
      ...segments,
    ]);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _getObject(Uri uri) async {
    final response = await _send((h) => _client.get(uri, headers: h));
    _check(response);
    final json = _decode(response);
    if (json is! Map<String, dynamic>) {
      throw const AdminFailure(unavailableMessage);
    }
    return json;
  }

  AdminList<T> _page<T>(
      Map<String, dynamic> json, T? Function(Object? item) parse) {
    final items = json['items'];
    if (items is! List) throw const AdminFailure(unavailableMessage);
    final next = json['nextCursor'];
    return AdminList(
      items: List.unmodifiable([
        for (final item in items)
          if (parse(item) case final parsed?) parsed,
      ]),
      nextCursor: next is String && next.isNotEmpty ? next : null,
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      return await _http.send(request);
    } on SessionExpiredException {
      throw const AdminFailure(sessionExpiredMessage, isSessionExpired: true);
    } on BackendUnreachableException {
      throw const AdminFailure(connectionErrorMessage);
    }
  }

  void _check(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    // Un 401 que llega aquí ya pasó por la renovación de AuthorizedHttp: la
    // sesión sigue viva y es el servicio el que no acepta el token. Se muestra
    // como error, sin sacar al ADMIN de su sesión.
    if (status == 403) {
      throw const AdminFailure(forbiddenMessage, statusCode: 403);
    }
    if (status >= 400 && status < 500) {
      final body = _decode(response);
      final detail = body is Map ? body['detail'] ?? body['title'] : null;
      throw AdminFailure(
        detail is String && detail.trim().isNotEmpty
            ? detail.trim()
            : status == 404
                ? notFoundMessage
                : unavailableMessage,
        statusCode: status,
      );
    }
    throw AdminFailure(unavailableMessage, statusCode: status);
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  static String? _text(Map json, String key) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static DateTime? _date(Map json, String key) =>
      DateTime.tryParse('${json[key]}');

  static AdminUser? _user(Object? json) {
    if (json is! Map) return null;
    final id = _text(json, 'id');
    final email = _text(json, 'email');
    if (id == null || email == null) return null;
    return AdminUser(
      id: id,
      email: email,
      firstName: _text(json, 'firstName') ?? '',
      lastName: _text(json, 'lastName') ?? '',
      role: AdminUserRole.fromApi(json['role']),
      status: AdminUserStatus.fromApi(json['status']),
      createdAt: _date(json, 'createdAt'),
    );
  }

  static AdminUserDetail? _userDetail(Object? json) {
    final base = _user(json);
    if (base == null || json is! Map) return null;
    return AdminUserDetail(
      id: base.id,
      email: base.email,
      firstName: base.firstName,
      lastName: base.lastName,
      role: base.role,
      status: base.status,
      createdAt: base.createdAt,
      phone: _text(json, 'phone'),
      documentType: _text(json, 'documentType'),
      documentNumberMasked: _text(json, 'documentNumberMasked'),
      verificationStatus: _text(json, 'verificationStatus'),
      companyName: _text(json, 'companyName'),
    );
  }

  static AdminPayment? _payment(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      final payment = ServicePayment.fromJson(json);
      final kind = RefundKind.fromApi(json['refundKind']);
      return AdminPayment(
        payment: payment,
        clientId: _text(json, 'clientId'),
        providerId: _text(json, 'providerId'),
        createdAt: _date(json, 'createdAt'),
        // Solo se ofrece si el backend dice que procede y de qué tipo sería.
        refundKind: json['refundable'] == true ? kind : null,
      );
    } on FormatException {
      return null;
    }
  }

  static AdminAuditEvent? _auditEvent(Object? json) {
    if (json is! Map) return null;
    final id = _text(json, 'id');
    final adminId = _text(json, 'adminId');
    final action = _text(json, 'action');
    final outcome = _text(json, 'outcome');
    if (id == null || adminId == null || action == null || outcome == null) {
      return null;
    }
    final details = json['details'];
    return AdminAuditEvent(
      id: id,
      adminId: adminId,
      action: action,
      outcome: outcome,
      occurredAt: _date(json, 'occurredAt'),
      targetType: _text(json, 'targetType'),
      targetId: _text(json, 'targetId'),
      details: details == null
          ? null
          : details is String
              ? details
              : jsonEncode(details),
    );
  }

  static String? _holdApi(HoldStatus status) => switch (status) {
        HoldStatus.notApplicable => 'NotApplicable',
        HoldStatus.pending => 'Pending',
        HoldStatus.held => 'Held',
        HoldStatus.failed => 'Failed',
        HoldStatus.captured => 'Captured',
        HoldStatus.released => 'Released',
        HoldStatus.reversed => 'Reversed',
        HoldStatus.unknown => null,
      };
}
