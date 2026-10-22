import '../../../../core/constants/service_category.dart';
import '../../../../core/constants/verification_status.dart';
import '../application/ports/provider_profile_repository.dart';
import '../domain/provider_public_profile.dart';
import '../domain/service_request_exceptions.dart';

/// Id del técnico que simula la sesión en las pruebas locales (el mismo que
/// se postula en el flujo E2E).
const demoTechnicianProviderId = 'prestador-demo';

const mockProviderProfiles = <ProviderPublicProfile>[
  ProviderPublicProfile(
    providerId: demoTechnicianProviderId,
    displayName: 'Carlos Ramírez',
    approximateZone: 'Chapinero, Bogotá',
    verificationStatus: VerificationStatus.valid,
    verifiedCategories: {ServiceCategory.plumbing, ServiceCategory.maintenance},
    description:
        'Plomero con experiencia en reparación de fugas, instalación de '
        'grifería y mantenimiento de redes hidráulicas en vivienda.',
    yearsOfExperience: 8,
    averageRating: 4.8,
    ratingCount: 36,
    completedJobs: [
      CompletedJob(
        title: 'Cambio de tubería en baño',
        category: ServiceCategory.plumbing,
        dateLabel: 'Septiembre 2026',
      ),
      CompletedJob(
        title: 'Reparación de fuga en cocina',
        category: ServiceCategory.plumbing,
        dateLabel: 'Agosto 2026',
      ),
    ],
    reviews: [
      ProviderReview(
        authorName: 'Laura M.',
        rating: 5,
        comment: 'Llegó puntual y dejó todo limpio. Muy recomendado.',
        dateLabel: 'Hace 2 semanas',
      ),
      ProviderReview(
        authorName: 'Andrés P.',
        rating: 5,
        comment: 'Explicó el problema con claridad y el precio fue justo.',
        dateLabel: 'Hace 1 mes',
      ),
      ProviderReview(
        authorName: 'Sofía R.',
        rating: 4,
        comment: 'Buen trabajo, tardó un poco más de lo previsto.',
        dateLabel: 'Hace 2 meses',
      ),
    ],
  ),
  ProviderPublicProfile(
    providerId: 'prestador-hidrosur',
    displayName: 'HidroSur Servicios',
    approximateZone: 'Teusaquillo, Bogotá',
    isCompany: true,
    verificationStatus: VerificationStatus.valid,
    verifiedCategories: {ServiceCategory.plumbing},
    description:
        'Empresa de plomería con cuadrilla propia y garantía por escrito en '
        'cada intervención.',
    yearsOfExperience: 12,
    averageRating: 4.5,
    ratingCount: 112,
    completedJobs: [
      CompletedJob(
        title: 'Reposición de red de agua en conjunto residencial',
        category: ServiceCategory.plumbing,
        dateLabel: 'Octubre 2026',
      ),
    ],
    reviews: [
      ProviderReview(
        authorName: 'Camilo T.',
        rating: 4,
        comment: 'Equipo profesional, la cotización fue muy detallada.',
        dateLabel: 'Hace 3 semanas',
      ),
    ],
  ),
  ProviderPublicProfile(
    providerId: 'prestador-nuevo',
    displayName: 'Julián Torres',
    approximateZone: 'Usaquén, Bogotá',
    verificationStatus: VerificationStatus.pending,
    verifiedCategories: {},
    description: 'Técnico en mantenimiento general, recién registrado.',
    yearsOfExperience: 2,
  ),
];

/// Perfiles públicos locales para pruebas sin red y para el flujo E2E.
class MockProviderProfileRepository implements ProviderProfileRepository {
  MockProviderProfileRepository({
    List<ProviderPublicProfile> profiles = mockProviderProfiles,
  }) : _profiles = {
          for (final profile in profiles) profile.providerId: profile
        };

  final Map<String, ProviderPublicProfile> _profiles;

  @override
  Future<ProviderPublicProfile> getPublicProfile(String providerId) async {
    final profile = _profiles[providerId];
    if (profile == null) {
      throw const ServiceRequestFailure(
        'No encontramos el perfil de este prestador.',
      );
    }
    return profile;
  }
}
