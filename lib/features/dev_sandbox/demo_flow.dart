import '../client/service_requests/infrastructure/mock_provider_profile_repository.dart';
import '../client/service_requests/infrastructure/mock_service_request_repository.dart';
import '../quotations/infrastructure/mock_quotation_repository.dart';
import '../technician/applications/infrastructure/mock_application_repository.dart';

/// Datos en memoria compartidos por el técnico y el cliente mientras la
/// publicación real de solicitudes no esté integrada (GC-344, GC-349, GC-350,
/// GC-355 y GC-360). Lo que hace un rol queda visible para el otro en la misma
/// sesión de la app: la postulación aparece entre los postulantes, la selección
/// habilita la cotización y la cotización llega al cliente.
class DemoFlow {
  DemoFlow({this.latency = const Duration(milliseconds: 300)}) {
    reset();
  }

  /// Latencia simulada de la postulación (en pruebas, cero).
  final Duration latency;

  /// Solicitud de demostración que recorre todo el flujo.
  static const requestId = MockServiceRequestRepository.demoRequestId;
  static const requestSummary = 'Fuga en el lavaplatos';
  static const providerId = demoTechnicianProviderId;
  static const providerName = 'Carlos Ramírez';

  late MockServiceRequestRepository requests;
  late MockProviderProfileRepository profiles;
  late MockApplicationRepository applications;
  late MockQuotationRepository quotations;

  /// Vuelve al estado inicial del flujo.
  void reset() {
    requests = MockServiceRequestRepository.demo();
    profiles = MockProviderProfileRepository();
    quotations = MockQuotationRepository(providerId: providerId);
    applications = MockApplicationRepository(
      latency: latency,
      onApplied: (application) =>
          requests.addApplicant(application.serviceRequest.id, providerId),
    );
  }

  /// Solicitudes en las que el cliente ya seleccionó al técnico de la demo.
  Future<Set<String>> selectedRequestIds() async {
    final all = await requests.listMine();
    return {
      for (final request in all)
        if (request.selectedProviderId == providerId) request.id,
    };
  }
}
