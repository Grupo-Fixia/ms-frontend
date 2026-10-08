import '../domain/professional_profile_update.dart';
import '../domain/technician_profile.dart';
import '../domain/technician_profile_exceptions.dart';
import 'ports/technician_profile_repository.dart';

/// Caso de uso: registrar o actualizar el perfil profesional (GC-237).
///
/// Si la información no es válida no se envía nada al backend.
class UpdateTechnicianProfile {
  const UpdateTechnicianProfile(this._repository);

  static const invalidMessage = 'Revisa los datos marcados en el perfil.';

  final TechnicianProfileRepository _repository;

  Future<TechnicianProfile> call(ProfessionalProfileUpdate update) async {
    final errors = update.validationErrors;
    if (errors.isNotEmpty) {
      throw TechnicianProfileFailure(invalidMessage, fieldErrors: errors);
    }
    return _repository.updateProfile(update);
  }
}
