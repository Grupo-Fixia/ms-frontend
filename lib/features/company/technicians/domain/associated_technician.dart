import '../../../../core/constants/service_category.dart';
import '../../../technician/profile/domain/verification_status.dart';

export '../../../technician/profile/domain/verification_status.dart';

/// Técnico asociado a la empresa autenticada (GC-466, GC-467), con los mismos
/// campos del perfil público (GC-425): nunca correo, teléfono ni documento.
///
/// [userId] es el identificador que ms-services espera en `technicianId` al
/// postular a la empresa (GC-468) y el que aparece en `eligibleTechnicianIds`
/// de sus oportunidades.
///
/// Los campos que el técnico no ha llenado llegan en `null` (las
/// especialidades, como lista vacía); el frontend no los completa.
class AssociatedTechnician {
  const AssociatedTechnician({
    required this.userId,
    this.displayName,
    this.verificationStatus,
    this.categories = const [],
    this.professionalDescription,
    this.yearsOfExperience,
    this.city,
  });

  final String userId;
  final String? displayName;
  final VerificationStatus? verificationStatus;
  final List<ServiceCategory> categories;
  final String? professionalDescription;
  final int? yearsOfExperience;
  final String? city;

  /// Nombre para mostrar; si el técnico no tiene nombre público, un texto
  /// neutro en vez de inventar uno.
  String get name {
    final value = displayName?.trim();
    return value == null || value.isEmpty ? 'Técnico sin nombre público' : value;
  }

  bool get isVerified => verificationStatus == VerificationStatus.valid;
}
