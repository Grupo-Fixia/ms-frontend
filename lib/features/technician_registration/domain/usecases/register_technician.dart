import '../entities/technician_registration.dart';
import '../repositories/technician_registration_repository.dart';

class RegisterTechnician {
  const RegisterTechnician(this._repository);

  final TechnicianRegistrationRepository _repository;

  Future<void> call(TechnicianRegistration registration) async {
    final missingFields = registration.missingRequiredFields;
    if (missingFields.isNotEmpty) {
      throw InvalidTechnicianRegistrationException(missingFields);
    }

    if (registration.role != TechnicianRole.professional) {
      throw StateError('El registro de técnico debe usar el rol PROFESSIONAL.');
    }

    await _repository.register(registration);
  }
}

class InvalidTechnicianRegistrationException implements Exception {
  const InvalidTechnicianRegistrationException(this.missingFields);

  final List<String> missingFields;
}

class TechnicianRegistrationFailure implements Exception {
  const TechnicianRegistrationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
