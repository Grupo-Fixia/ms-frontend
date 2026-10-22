import '../../../../core/constants/service_category.dart';
import '../application/ports/application_repository.dart';
import '../domain/application_exceptions.dart';
import '../domain/service_application.dart';

/// Postulaciones en memoria para probar sin red (`USE_MOCK_APPLICATIONS`) y
/// para el flujo de pruebas E2E. Imita las respuestas del backend: `409` si
/// el técnico ya se postuló y los fallos que se le indiquen en [failures]
/// (por ejemplo `403` o `422`).
class MockApplicationRepository implements ApplicationRepository {
  MockApplicationRepository({
    Map<String, ApplicationFailure> failures = const {},
    this.onApplied,
    this.latency = const Duration(milliseconds: 300),
  }) : _failures = Map.of(failures);

  final Map<String, ApplicationFailure> _failures;
  final Duration latency;

  /// Se llama cuando se registra una postulación nueva.
  final void Function(ServiceApplication application)? onApplied;

  final List<ServiceApplication> _applications = [];

  @override
  Future<ServiceApplication> apply(String serviceRequestId) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = _failures[serviceRequestId];
    if (failure != null) throw failure;
    for (final existing in _applications) {
      if (existing.serviceRequest.id == serviceRequestId) {
        throw ApplicationFailure(
          'Ya te postulaste a esta solicitud.',
          existingApplicationId: existing.id,
        );
      }
    }
    final now = DateTime.now();
    final application = ServiceApplication(
      id: 'mock-application-${_applications.length + 1}',
      status: ApplicationStatus.applied,
      serviceRequest: ApplicationRequestSummary(
        id: serviceRequestId,
        category: ServiceCategory.plumbing,
        city: 'Bogotá',
        zone: 'Chapinero',
      ),
      createdAt: now,
      updatedAt: now,
    );
    _applications.insert(0, application);
    onApplied?.call(application);
    return application;
  }

  @override
  Future<List<ServiceApplication>> listMine() async =>
      List.unmodifiable(_applications);

  @override
  Future<ServiceApplication> getMine(String id) async {
    for (final application in _applications) {
      if (application.id == id) return application;
    }
    throw const ApplicationFailure('No encontramos esa postulación.');
  }
}
