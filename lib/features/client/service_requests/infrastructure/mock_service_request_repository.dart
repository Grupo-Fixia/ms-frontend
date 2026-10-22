import '../../../../core/constants/service_category.dart';
import '../application/ports/service_request_repository.dart';
import '../domain/applicant.dart';
import '../domain/service_request.dart';
import '../domain/service_request_exceptions.dart';

/// Solicitudes del cliente y sus postulantes en memoria, para pruebas sin red
/// y para el flujo E2E (GC-349). Imita al backend: al seleccionar un
/// prestador la solicitud pasa a `providerSelected` y las demás postulaciones
/// quedan rechazadas.
class MockServiceRequestRepository implements ServiceRequestRepository {
  MockServiceRequestRepository({
    List<ServiceRequest> requests = const [],
    Map<String, List<Applicant>> applicants = const {},
  })  : _requests = List.of(requests),
        _applicants = {
          for (final entry in applicants.entries) entry.key: [...entry.value],
        };

  /// Id de la solicitud de demostración. Coincide con una oportunidad de
  /// `mockServiceOpportunities` para que la postulación del técnico llegue
  /// aquí.
  static const demoRequestId = 'fuga-lavaplatos';

  /// Una solicitud publicada con dos postulantes ya recibidos.
  factory MockServiceRequestRepository.demo() {
    final now = DateTime.now();
    return MockServiceRequestRepository(
      requests: [
        ServiceRequest(
          id: demoRequestId,
          category: ServiceCategory.plumbing,
          description: 'Hay una fuga constante en la conexión del lavaplatos. '
              'Se requiere revisar la tubería y cambiar las piezas que hagan '
              'falta.',
          status: ServiceRequestStatus.published,
          approximateLocation: const ApproximateLocation(
            city: 'Bogotá',
            zone: 'Chapinero',
          ),
          expectedAt: now.add(const Duration(days: 1)),
          publishedAt: now,
        ),
      ],
      applicants: {
        demoRequestId: [
          Applicant(
            id: 'postulacion-hidrosur',
            providerId: 'prestador-hidrosur',
            status: ApplicationStatus.applied,
            createdAt: now.subtract(const Duration(minutes: 20)),
          ),
          Applicant(
            id: 'postulacion-nuevo',
            providerId: 'prestador-nuevo',
            status: ApplicationStatus.applied,
            createdAt: now.subtract(const Duration(minutes: 5)),
          ),
        ],
      },
    );
  }

  final List<ServiceRequest> _requests;
  final Map<String, List<Applicant>> _applicants;
  int _sequence = 0;

  /// Registra la postulación de [providerId] (la hace el técnico en el flujo
  /// E2E). No duplica si ya estaba.
  void addApplicant(String requestId, String providerId) {
    final list = _applicants.putIfAbsent(requestId, () => []);
    if (list.any((applicant) => applicant.providerId == providerId)) return;
    list.add(
      Applicant(
        id: 'postulacion-${++_sequence}-$providerId',
        providerId: providerId,
        status: ApplicationStatus.applied,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ServiceRequest> publish(NewServiceRequest request) async {
    final created = ServiceRequest(
      id: 'solicitud-${++_sequence}',
      category: request.category ?? ServiceCategory.maintenance,
      description: request.description,
      status: ServiceRequestStatus.published,
      approximateLocation: request.approximateLocation,
      expectedAt: request.expectedAt ?? DateTime.now(),
      publishedAt: DateTime.now(),
    );
    _requests.insert(0, created);
    return created;
  }

  @override
  Future<List<ServiceRequest>> listMine() async => List.unmodifiable(_requests);

  @override
  Future<ServiceRequest> getMine(String id) async => _find(id);

  @override
  Future<List<Applicant>> listApplicants(String requestId) async {
    _find(requestId);
    return List.unmodifiable(_applicants[requestId] ?? const <Applicant>[]);
  }

  @override
  Future<ServiceRequest> selectProvider(
    String requestId,
    String applicationId,
  ) async {
    final request = _find(requestId);
    final list = _applicants[requestId] ?? [];
    final index = list.indexWhere((applicant) => applicant.id == applicationId);
    if (index < 0) {
      throw const ServiceRequestFailure(
        'No encontramos esa postulación en tu solicitud.',
      );
    }
    final chosen = list[index];
    if (request.selectedProviderId != null &&
        request.selectedProviderId != chosen.providerId) {
      throw const ServiceRequestFailure(
        'Esta solicitud ya tiene un prestador seleccionado.',
      );
    }
    final now = DateTime.now();
    for (var i = 0; i < list.length; i++) {
      final applicant = list[i];
      list[i] = Applicant(
        id: applicant.id,
        providerId: applicant.providerId,
        status: i == index
            ? ApplicationStatus.selected
            : ApplicationStatus.rejected,
        createdAt: applicant.createdAt,
        updatedAt: now,
      );
    }
    final updated = ServiceRequest(
      id: request.id,
      category: request.category,
      description: request.description,
      status: ServiceRequestStatus.providerSelected,
      approximateLocation: request.approximateLocation,
      expectedAt: request.expectedAt,
      selectedProviderId: chosen.providerId,
      publishedAt: request.publishedAt,
      updatedAt: now,
    );
    _requests[_requests.indexWhere((r) => r.id == requestId)] = updated;
    return updated;
  }

  ServiceRequest _find(String id) {
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    throw const ServiceRequestFailure('No encontramos esa solicitud.');
  }
}
