import '../domain/technician_profile.dart';
import 'ports/technician_profile_repository.dart';

/// Caso de uso: consultar el perfil profesional del técnico (GC-237).
class GetTechnicianProfile {
  const GetTechnicianProfile(this._repository);

  final TechnicianProfileRepository _repository;

  Future<TechnicianProfile> call() => _repository.fetchProfile();
}
