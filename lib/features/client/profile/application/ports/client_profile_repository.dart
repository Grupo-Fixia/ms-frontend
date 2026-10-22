import '../../domain/client_profile.dart';
import '../../domain/client_profile_update.dart';

/// Puerto de salida: perfil del cliente autenticado (GC-320).
///
/// Ambos métodos lanzan `ClientProfileFailure` si el backend rechaza la
/// solicitud o no se puede contactar.
abstract interface class ClientProfileRepository {
  Future<ClientProfile> fetchProfile();

  /// Reemplaza nombre, apellido y teléfono; devuelve el perfil guardado.
  Future<ClientProfile> updateProfile(ClientProfileUpdate update);
}
