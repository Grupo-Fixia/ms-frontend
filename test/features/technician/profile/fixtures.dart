import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/domain/verification_status.dart';

/// Técnico recién registrado: perfil vacío y pendiente de verificación.
const emptyProfile = TechnicianProfile(
  technicianId: 'tec-1',
  verificationStatus: VerificationStatus.pending,
);

TechnicianProfile completeProfile({
  VerificationStatus status = VerificationStatus.pending,
  int years = 8,
  Set<ServiceCategory> categories = const {
    ServiceCategory.plumbing,
    ServiceCategory.electrical,
  },
  String description = 'Plomero con experiencia en redes residenciales.',
}) {
  return TechnicianProfile(
    technicianId: 'tec-1',
    verificationStatus: status,
    professionalDescription: description,
    yearsOfExperience: years,
    categories: categories,
    updatedAt: DateTime(2026, 10, 8, 10),
  );
}
