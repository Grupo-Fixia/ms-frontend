import '../../../../core/constants/application_status.dart';

export '../../../../core/constants/application_status.dart';

/// Prestador postulado a una solicitud del cliente (GC-299, RF-016), tal
/// como lo ve el cliente dueño. El perfil público del prestador se consulta
/// aparte con [providerId].
class Applicant {
  const Applicant({
    required this.id,
    required this.providerId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  /// Identificador de la postulación (se usa para seleccionar al prestador).
  final String id;

  /// Identificador del prestador en ms-users.
  final String providerId;
  final ApplicationStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
