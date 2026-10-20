import '../../../../core/constants/service_category.dart';
import '../application/ports/technician_profile_repository.dart';
import '../domain/professional_profile_update.dart';
import '../domain/technician_profile.dart';
import '../domain/verification_status.dart';

/// Repositorio en memoria para probar el perfil del técnico sin autenticación.
class DemoTechnicianProfileRepository implements TechnicianProfileRepository {
  TechnicianProfile _profile = const TechnicianProfile(
    technicianId: 'demo-technician',
    verificationStatus: VerificationStatus.pending,
    professionalDescription:
        'Técnico con experiencia en reparaciones residenciales, instalaciones '
        'y mantenimiento preventivo. Trabajo con cuidado y atención al detalle.',
    yearsOfExperience: 8,
    categories: {
      ServiceCategory.plumbing,
      ServiceCategory.electrical,
    },
  );

  @override
  Future<TechnicianProfile> fetchProfile() async => _profile;

  @override
  Future<TechnicianProfile> updateProfile(
    ProfessionalProfileUpdate update,
  ) async {
    _profile = TechnicianProfile(
      technicianId: _profile.technicianId,
      verificationStatus: _profile.verificationStatus,
      professionalDescription: update.professionalDescription,
      yearsOfExperience: update.yearsOfExperience,
      categories: Set.unmodifiable(update.categories),
      updatedAt: DateTime.now(),
    );
    return _profile;
  }
}
