import '../domain/account_registration.dart';
import '../domain/registration_exceptions.dart';
import 'ports/account_registration_repository.dart';

/// Caso de uso: registrar una cuenta de cliente o de técnico (GC-234, GC-235).
///
/// El rol lo define el repositorio que se inyecta (cada rol tiene su endpoint).
class RegisterAccount {
  const RegisterAccount(this._repository);

  final AccountRegistrationRepository _repository;

  Future<void> call(AccountRegistration registration) async {
    final missingFields = registration.missingRequiredFields;
    if (missingFields.isNotEmpty) {
      throw InvalidRegistrationException(missingFields);
    }
    await _repository.register(registration);
  }
}
