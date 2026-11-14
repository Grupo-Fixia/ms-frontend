import '../../payments/domain/payments.dart';

/// Panel web del ADMIN de Fixia (GC-536), contrato `ms-users/docs/contracts/
/// admin.md` (GC-534). El ADMIN consulta usuarios y pagos, ve el registro de
/// sus acciones y ejecuta una sola acción: el reembolso de ms-payments.

class AdminFailure implements Exception {
  const AdminFailure(this.message,
      {this.isSessionExpired = false, this.statusCode});

  final String message;
  final bool isSessionExpired;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Rol de una cuenta, como lo escribe ms-users.
enum AdminUserRole {
  client('CLIENT', 'Cliente'),
  professional('PROFESSIONAL', 'Técnico'),
  company('COMPANY', 'Empresa'),
  admin('ADMIN', 'Administrador');

  const AdminUserRole(this.api, this.label);

  final String api;
  final String label;

  static AdminUserRole? fromApi(Object? value) {
    for (final role in values) {
      if (role.api == value) return role;
    }
    return null;
  }
}

enum AdminUserStatus {
  active('ACTIVE', 'Activa'),
  disabled('DISABLED', 'Deshabilitada');

  const AdminUserStatus(this.api, this.label);

  final String api;
  final String label;

  static AdminUserStatus? fromApi(Object? value) {
    for (final status in values) {
      if (status.api == value) return status;
    }
    return null;
  }
}

/// Usuario en la lista: sin documento ni teléfono (contrato §3.1).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final AdminUserRole? role;
  final AdminUserStatus? status;
  final DateTime? createdAt;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }
}

/// Detalle de un usuario (§3.2): el documento llega enmascarado.
class AdminUserDetail extends AdminUser {
  const AdminUserDetail({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.role,
    required super.status,
    required super.createdAt,
    this.phone,
    this.documentType,
    this.documentNumberMasked,
    this.verificationStatus,
    this.companyName,
  });

  final String? phone;
  final String? documentType;
  final String? documentNumberMasked;
  final String? verificationStatus;
  final String? companyName;
}

/// Qué haría un reembolso hoy (§4.1).
enum RefundKind {
  release('RELEASE', 'Liberar el saldo retenido al cliente'),
  reversal('REVERSAL', 'Revertir el cobro: prestador y Fixia devuelven'),
  gateway('GATEWAY', 'Reembolsar por la pasarela simulada');

  const RefundKind(this.api, this.description);

  final String api;
  final String description;

  static RefundKind? fromApi(Object? value) {
    for (final kind in values) {
      if (kind.api == value) return kind;
    }
    return null;
  }
}

/// Un pago en la lista del ADMIN: el pago de siempre más si procede el
/// reembolso y de qué tipo sería.
class AdminPayment {
  const AdminPayment({
    required this.payment,
    required this.clientId,
    required this.providerId,
    required this.createdAt,
    required this.refundKind,
  });

  final ServicePayment payment;
  final String? clientId;
  final String? providerId;
  final DateTime? createdAt;

  /// `null` si hoy no procede un reembolso.
  final RefundKind? refundKind;

  /// El panel nunca ofrece «Reembolsar» si el backend no lo permite (§6).
  bool get refundable => refundKind != null;

  String get id => payment.id;
}

/// De qué servicio viene una acción registrada (cada uno guarda las suyas).
enum AuditSource {
  users('Usuarios'),
  payments('Pagos');

  const AuditSource(this.label);

  final String label;
}

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.adminId,
    required this.action,
    required this.outcome,
    required this.occurredAt,
    this.targetType,
    this.targetId,
    this.details,
  });

  final String id;
  final String adminId;
  final String action;
  final String outcome;
  final DateTime? occurredAt;
  final String? targetType;
  final String? targetId;

  /// JSON pequeño del backend (filtros o motivo), ya como texto.
  final String? details;

  String get actionLabel => switch (action) {
        'USER_LIST' => 'Consultó la lista de usuarios',
        'USER_VIEW' => 'Consultó un usuario',
        'PAYMENT_LIST' => 'Consultó la lista de pagos',
        'PAYMENT_VIEW' => 'Consultó un pago',
        'PAYMENT_REFUND' => 'Reembolsó un pago',
        'AUDIT_LIST' => 'Consultó el registro de acciones',
        _ => action,
      };

  String get outcomeLabel => switch (outcome) {
        'OK' => 'Correcto',
        'DENIED' => 'Denegado',
        'CONFLICT' => 'Conflicto',
        'NOT_FOUND' => 'No encontrado',
        _ => outcome,
      };
}

/// Página de una lista paginada por cursor.
class AdminList<T> {
  const AdminList({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

/// Lo que el panel necesita del backend.
abstract interface class AdminGateway {
  Future<AdminList<AdminUser>> users({
    AdminUserRole? role,
    AdminUserStatus? status,
    String? query,
    String? cursor,
  });

  Future<AdminUserDetail> user(String id);

  Future<AdminList<AdminPayment>> payments({
    HoldStatus? holdStatus,
    String? userId,
    String? cursor,
  });

  /// Reembolso de ms-payments (GC-487). [idempotencyKey] se genera una vez
  /// por intento y se reutiliza en los reintentos, para no devolver dos veces.
  Future<ServicePayment> refund(
    String paymentId, {
    required String reason,
    required String idempotencyKey,
  });

  Future<AdminList<AdminAuditEvent>> auditEvents(
    AuditSource source, {
    String? cursor,
  });
}

/// Motivo obligatorio del reembolso, máximo 500 caracteres (§4.3).
String? validateRefundReason(String? value) {
  final reason = value?.trim() ?? '';
  if (reason.isEmpty) return 'Escribe el motivo del reembolso.';
  if (reason.length > 500) return 'Máximo 500 caracteres.';
  return null;
}

/// Búsqueda de usuarios: vacía o de 2 a 100 caracteres (§3.1).
String? normalizeUserQuery(String value) {
  final query = value.trim();
  if (query.length < 2) return null;
  return query.length > 100 ? query.substring(0, 100) : query;
}
