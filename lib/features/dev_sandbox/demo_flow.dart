import '../client/dashboard/presentation/client_dashboard_page.dart';
import '../client/service_requests/infrastructure/mock_provider_profile_repository.dart';
import '../client/service_requests/infrastructure/mock_service_request_repository.dart';
import '../quotations/domain/quotation.dart';
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

  /// Cotizaciones de ejemplo ya recibidas por el cliente: una vigente con
  /// materiales, otra vigente para rechazar y otra vencida.
  static const receivedQuotes = [
    ReceivedQuoteSummary(
      requestId: 'pintura-habitacion',
      title: 'Pintura de habitación',
      providerName: 'Sofía Méndez',
    ),
    ReceivedQuoteSummary(
      requestId: 'lamparas-sala',
      title: 'Instalación de lámparas',
      providerName: 'Camilo Díaz',
    ),
    ReceivedQuoteSummary(
      requestId: 'cerradura-puerta',
      title: 'Cambio de cerradura',
      providerName: 'Luis Herrera',
    ),
  ];

  /// Resumen de la solicitud que tiene cotización de ejemplo (o la de la demo).
  static ReceivedQuoteSummary summaryOf(String requestId) =>
      receivedQuotes.firstWhere(
        (quote) => quote.requestId == requestId,
        orElse: () => ReceivedQuoteSummary(
          requestId: requestId,
          title: requestSummary,
          providerName: providerName,
        ),
      );

  late MockServiceRequestRepository requests;
  late MockProviderProfileRepository profiles;
  late MockApplicationRepository applications;
  late MockQuotationRepository quotations;

  /// Vuelve al estado inicial del flujo.
  void reset() {
    requests = MockServiceRequestRepository.demo();
    profiles = MockProviderProfileRepository();
    quotations = MockQuotationRepository(providerId: providerId);
    _seedQuotations();
    applications = MockApplicationRepository(
      latency: latency,
      onApplied: (application) =>
          requests.addApplicant(application.serviceRequest.id, providerId),
    );
  }

  void _seedQuotations() {
    final now = DateTime.now();
    Quotation build({
      required String requestId,
      required String provider,
      required int cents,
      required String scope,
      required String conditions,
      required Duration validFor,
      QuotationStatus status = QuotationStatus.sent,
      List<QuotationMaterial> materials = const [],
    }) =>
        Quotation(
          id: 'demo-$requestId',
          serviceRequestId: requestId,
          providerId: provider,
          amountInCents: cents,
          currency: 'COP',
          scope: scope,
          conditions: conditions,
          agreedAt: now.add(const Duration(days: 3)),
          validUntil: now.add(validFor),
          status: status,
          statusName: status.label,
          materials: materials,
          createdAt: now.subtract(const Duration(hours: 5)),
          updatedAt: now.subtract(const Duration(hours: 5)),
        );
    quotations
      ..seed(build(
        requestId: 'pintura-habitacion',
        provider: 'prestador-sofia',
        cents: 52000000,
        scope: 'Pintura de paredes y techo de una habitación de 12 m², con '
            'dos manos de vinilo y resane previo.',
        conditions: 'Incluye protección de muebles y limpieza final. '
            'Garantía de 6 meses sobre el acabado.',
        validFor: const Duration(days: 5),
        materials: const [
          QuotationMaterial(
              name: 'Vinilo tipo 1 (galón)', amountInCents: 9500000),
          QuotationMaterial(name: 'Estuco y lijas', amountInCents: 2800000),
        ],
      ))
      ..seed(build(
        requestId: 'lamparas-sala',
        provider: 'camilo-diaz',
        cents: 31000000,
        scope: 'Instalación de tres lámparas de techo y cambio de dos '
            'interruptores en la sala.',
        conditions: 'Pago 50 % al iniciar y 50 % al finalizar.',
        validFor: const Duration(days: 2),
      ))
      ..seed(build(
        requestId: 'cerradura-puerta',
        provider: 'prestador-luis',
        cents: 18000000,
        scope: 'Cambio de cerradura de la puerta principal.',
        conditions: 'La cotización venció; el prestador debe enviar otra.',
        validFor: const Duration(days: -1),
        status: QuotationStatus.expired,
      ));
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
