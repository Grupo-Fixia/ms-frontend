import '../../domain/account_registration.dart';

/// Puerto de salida: cómo se envía el registro (lo implementa
/// infraestructura, GC-253).
abstract interface class AccountRegistrationRepository {
  /// Lanza `RegistrationFailure` si el backend rechaza el registro.
  Future<void> register(AccountRegistration registration);
}
