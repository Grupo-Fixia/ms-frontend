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
  ProviderPublicProfile(
    providerId: 'ana-garcia',
    displayName: 'Ana García',
    approximateZone: 'Usaquén, Bogotá',
    verificationStatus: VerificationStatus.valid,
    verifiedCategories: {ServiceCategory.plumbing},
    description: 'Plomera con 6 años de experiencia en reparaciones y '
        'adecuaciones de baños y cocinas.',
    yearsOfExperience: 6,
    averageRating: 4.8,
    ratingCount: 64,
    completedJobs: [
      CompletedJob(
        title: 'Cambio de grifería en cocina',
        category: ServiceCategory.plumbing,
        dateLabel: 'Octubre 2026',
      ),
    ],
    reviews: [
      ProviderReview(
        authorName: 'Marcela V.',
        rating: 5,
        comment: 'Resolvió la filtración el mismo día.',
        dateLabel: 'Hace 1 semana',
      ),
    ],
  ),
  ProviderPublicProfile(
    providerId: 'pedro-rojas',
    displayName: 'Pedro Rojas',
    approximateZone: 'Teusaquillo, Bogotá',
    verificationStatus: VerificationStatus.valid,
    verifiedCategories: {ServiceCategory.painting},
    description: 'Pintor de interiores y fachadas, trabajo limpio y con '
        'acabados garantizados.',
    yearsOfExperience: 10,
    averageRating: 4.7,
    ratingCount: 112,
    completedJobs: [
      CompletedJob(
        title: 'Pintura de apartamento de 70 m²',
        category: ServiceCategory.painting,
        dateLabel: 'Septiembre 2026',
      ),
    ],
    reviews: [
      ProviderReview(
        authorName: 'Julia C.',
        rating: 5,
        comment: 'Cubrió los muebles y dejó todo impecable.',
        dateLabel: 'Hace 3 semanas',
      ),
    ],
  ),
  ProviderPublicProfile(
    providerId: 'laura-torres',
    displayName: 'Laura Torres',
    approximateZone: 'Suba, Bogotá',
    verificationStatus: VerificationStatus.valid,
    verifiedCategories: {ServiceCategory.maintenance},
    description: 'Especialista en limpieza profunda y mantenimiento de '
        'viviendas y oficinas.',
    yearsOfExperience: 7,
    averageRating: 5.0,
    ratingCount: 203,
    completedJobs: [
      CompletedJob(
        title: 'Limpieza profunda post-obra',
        category: ServiceCategory.maintenance,
        dateLabel: 'Octubre 2026',
      ),
    ],
    reviews: [
      ProviderReview(
        authorName: 'Ricardo S.',
        rating: 5,
        comment: 'Puntual y muy detallista.',
        dateLabel: 'Hace 2 semanas',
      ),
    ],
  ),
  ProviderPublicProfile(
    providerId: 'camilo-diaz',
    displayName: 'Camilo Díaz',
    approximateZone: 'Chapinero, Bogotá',
    verificationStatus: VerificationStatus.valid,
    verifiedCategories: {ServiceCategory.electrical},
    description: 'Electricista certificado en instalaciones residenciales '
        'y revisión de tableros.',
    yearsOfExperience: 9,
    averageRating: 4.9,
    ratingCount: 87,
    completedJobs: [
      CompletedJob(
        title: 'Cambio de tablero eléctrico',
        category: ServiceCategory.electrical,
        dateLabel: 'Agosto 2026',
      ),
    ],
    reviews: [
      ProviderReview(
        authorName: 'Natalia B.',
        rating: 5,
        comment: 'Explicó cada paso y dejó todo seguro.',
        dateLabel: 'Hace 1 mes',
      ),
    ],
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
