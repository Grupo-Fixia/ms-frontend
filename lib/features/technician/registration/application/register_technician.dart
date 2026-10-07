import '../domain/technician_registration.dart';
import '../domain/technician_registration_exceptions.dart';
import 'ports/technician_registration_repository.dart';

/// Caso de uso: registrar una cuenta de técnico.
class RegisterTechnician {
  const RegisterTechnician(this._repository);

  final TechnicianRegistrationRepository _repository;

  Future<void> call(TechnicianRegistration registration) async {
    final missingFields = registration.missingRequiredFields;
    if (missingFields.isNotEmpty) {
      throw InvalidTechnicianRegistrationException(missingFields);
    }
    await _repository.register(registration);
  }
}
