/// Invitaciones de una empresa a técnicos independientes (GC-525, lado de la
/// empresa). Contrato: `ms-users/docs/contracts/empresas.md` §4 (GC-523).
library;

enum InvitationStatus {
  pending('PENDING', 'Pendiente'),
  accepted('ACCEPTED', 'Aceptada'),
  rejected('REJECTED', 'Rechazada'),
  cancelled('CANCELLED', 'Cancelada'),
  expired('EXPIRED', 'Vencida');

  const InvitationStatus(this.api, this.label);

  final String api;
  final String label;

  static InvitationStatus? fromApi(Object? value) {
    for (final status in values) {
      if (status.api == value) return status;
    }
    return null;
  }
}

class CompanyInvitation {
  const CompanyInvitation({
    required this.id,
    required this.status,
    required this.technicianName,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  final String id;
  final InvitationStatus status;

  /// Nombre abreviado del técnico («Carlos G.»), como el perfil público.
  final String technicianName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  /// Solo se cancela una invitación pendiente (§4.3).
  bool get cancellable => status == InvitationStatus.pending;

  factory CompanyInvitation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = InvitationStatus.fromApi(json['status']);
    final technician = json['technician'];
    final name = technician is Map ? technician['displayName'] : null;
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final expiresAt = DateTime.tryParse('${json['expiresAt']}');
    if (id is! String ||
        id.isEmpty ||
        status == null ||
        createdAt == null ||
        expiresAt == null) {
      throw const FormatException('Invitación inválida');
    }
    return CompanyInvitation(
      id: id,
      status: status,
      technicianName:
          name is String && name.trim().isNotEmpty ? name.trim() : 'Técnico',
      createdAt: createdAt,
      expiresAt: expiresAt,
      respondedAt: DateTime.tryParse('${json['respondedAt']}'),
    );
  }
}

class InvitationFailure implements Exception {
  const InvitationFailure(this.message,
      {this.isSessionExpired = false, this.statusCode});

  final String message;
  final bool isSessionExpired;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class CompanyInvitationsGateway {
  Future<CompanyInvitation> invite(String technicianEmail);

  /// De la más reciente a la más antigua; [status] filtra.
  Future<List<CompanyInvitation>> list({InvitationStatus? status});

  Future<void> cancel(String invitationId);
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Correo del técnico: obligatorio, con forma de correo y máximo 254.
String? validateTechnicianEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Escribe el correo del técnico.';
  if (email.length > 254 || !_email.hasMatch(email)) {
    return 'Escribe un correo válido.';
  }
  return null;
}
