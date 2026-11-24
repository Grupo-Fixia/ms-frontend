/// El técnico frente a las empresas (GC-525, lado del técnico): invitaciones
/// que le llegaron, su empresa actual y desvincularse. Contrato:
/// `ms-users/docs/contracts/empresas.md` §5 (GC-524).
library;

/// Invitación abierta que le llegó al técnico.
class ReceivedInvitation {
  const ReceivedInvitation({
    required this.id,
    required this.companyName,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String companyName;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory ReceivedInvitation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final company = json['company'];
    final name = company is Map ? company['name'] : null;
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final expiresAt = DateTime.tryParse('${json['expiresAt']}');
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        createdAt == null ||
        expiresAt == null) {
      throw const FormatException('Invitación inválida');
    }
    return ReceivedInvitation(
      id: id,
      companyName: name.trim(),
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}

/// La empresa a la que pertenece el técnico.
class Membership {
  const Membership({required this.companyName, required this.joinedAt});

  final String companyName;
  final DateTime? joinedAt;

  factory Membership.fromJson(Map<String, dynamic> json) {
    final company = json['company'];
    final name = company is Map ? company['name'] : null;
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Empresa inválida');
    }
    return Membership(
      companyName: name.trim(),
      joinedAt: DateTime.tryParse('${json['joinedAt']}'),
    );
  }
}

/// Por qué no se puede desvincular todavía (§5.5).
enum LeaveBlocker {
  pendingWork('PENDING_WORK',
      'Tienes trabajos de la empresa sin terminar (por iniciar o en curso).'),
  heldBalance('HELD_BALANCE',
      'Hay dinero retenido en servicios que hiciste con la empresa.');

  const LeaveBlocker(this.api, this.message);

  final String api;
  final String message;

  static LeaveBlocker? fromApi(Object? value) {
    for (final b in values) {
      if (b.api == value) return b;
    }
    return null;
  }
}

class TechnicianCompanyFailure implements Exception {
  const TechnicianCompanyFailure(
    this.message, {
    this.isSessionExpired = false,
    this.statusCode,
    this.blockers = const [],
    this.serviceRequestIds = const [],
  });

  final String message;
  final bool isSessionExpired;
  final int? statusCode;

  /// Motivos de un 409 al desvincularse.
  final List<LeaveBlocker> blockers;
  final List<String> serviceRequestIds;

  @override
  String toString() => message;
}

abstract interface class TechnicianCompanyGateway {
  /// Invitaciones pendientes y vigentes.
  Future<List<ReceivedInvitation>> invitations();

  /// Devuelve la empresa a la que quedó asociado.
  Future<Membership> accept(String invitationId);

  Future<void> reject(String invitationId);

  /// `null` si es independiente.
  Future<Membership?> membership();

  Future<void> leave();
}
