import '../../../../core/constants/service_category.dart';
import '../../../../core/domain/reputation.dart';
import 'verification_status.dart';

/// Perfil profesional del técnico autenticado (GC-237, RF-009), como lo
/// devuelve `GET /api/users/technicians/me/profile`.
///
/// Los campos profesionales llegan vacíos hasta que el técnico los registra.
class TechnicianProfile {
  const TechnicianProfile({
    required this.technicianId,
    required this.verificationStatus,
    this.professionalDescription,
    this.yearsOfExperience,
    this.categories = const {},
    this.updatedAt,
    this.reputation,
  });

  /// Calificación que le dieron sus clientes (GC-446); `null` si aún no
  /// tiene ninguna.
  final Reputation? reputation;

  final String technicianId;
  final VerificationStatus? verificationStatus;
  final String? professionalDescription;
  final int? yearsOfExperience;
  final Set<ServiceCategory> categories;
  final DateTime? updatedAt;

  /// El técnico ya registró descripción, experiencia y al menos una categoría.
  bool get isComplete =>
      (professionalDescription?.trim().isNotEmpty ?? false) &&
      yearsOfExperience != null &&
      categories.isNotEmpty;
}
