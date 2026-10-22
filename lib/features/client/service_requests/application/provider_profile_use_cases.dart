import '../domain/provider_public_profile.dart';
import 'ports/provider_profile_repository.dart';

/// Caso de uso: consultar el perfil público de un prestador postulado
/// (GC-350).
class GetProviderPublicProfile {
  const GetProviderPublicProfile(this._repository);

  final ProviderProfileRepository _repository;

  Future<ProviderPublicProfile> call(String providerId) =>
      _repository.getPublicProfile(providerId.trim());
}
