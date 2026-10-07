import '../domain/client_registration.dart';
import '../domain/client_registration_exceptions.dart';
import 'ports/client_registration_repository.dart';

/// Caso de uso: registrar la cuenta de un cliente (GC-234).
class RegisterClient {
  const RegisterClient(this._repository);

  final ClientRegistrationRepository _repository;

  Future<void> call(ClientRegistration registration) async {
    final missingFields = registration.missingRequiredFields;
    if (missingFields.isNotEmpty) {
      throw InvalidClientRegistrationException(missingFields);
    }
    await _repository.register(registration);
  }
}
