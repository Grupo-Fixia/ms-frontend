import '../application/ports/technician_profile_repository.dart';
import '../domain/professional_profile_update.dart';
import '../domain/technician_profile.dart';
import '../domain/verification_status.dart';

/// Perfil guardado solo en memoria, mientras se conecta con
/// `/api/users/technicians/me/profile` de ms-users (GC-264). Arranca vacío y
/// pendiente de verificación, como queda un técnico recién registrado.
class InMemoryTechnicianProfileRepository
    implements TechnicianProfileRepository {
  InMemoryTechnicianProfileRepository({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  TechnicianProfile _profile = const TechnicianProfile(
    technicianId: 'local',
    verificationStatus: VerificationStatus.pending,
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
      categories: {...update.categories},
      updatedAt: _clock(),
    );
    return _profile;
  }
}
