import '../../domain/client_registration.dart';

/// Puerto de salida: cómo se envía el registro (lo implementa
/// infraestructura, GC-253).
abstract interface class ClientRegistrationRepository {
  /// Lanza `ClientRegistrationFailure` si el backend rechaza el registro.
  Future<void> register(ClientRegistration registration);
}
