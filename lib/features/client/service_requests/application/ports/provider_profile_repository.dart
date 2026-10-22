import '../../domain/provider_public_profile.dart';

/// Puerto de salida: perfil público de un prestador postulado (GC-350).
///
/// Lanza `ServiceRequestFailure` si no se encuentra o no se puede contactar.
abstract interface class ProviderProfileRepository {
  Future<ProviderPublicProfile> getPublicProfile(String providerId);
}
