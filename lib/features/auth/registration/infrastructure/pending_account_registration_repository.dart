import '../application/ports/account_registration_repository.dart';
import '../domain/account_registration.dart';
import '../domain/registration_exceptions.dart';

/// Repositorio temporal del registro de técnico mientras se conecta con
/// `POST /api/users/technicians` de ms-users (GC-256). No envía nada: informa
/// que el registro todavía no está disponible.
class PendingAccountRegistrationRepository
    implements AccountRegistrationRepository {
  const PendingAccountRegistrationRepository();

  static const unavailableMessage =
      'El registro de técnicos estará disponible muy pronto.';

  @override
  Future<void> register(AccountRegistration registration) async {
    throw const RegistrationFailure(unavailableMessage);
  }
}
