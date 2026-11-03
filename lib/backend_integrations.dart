import 'features/service_evidence/application/evidence_feature.dart';
import 'features/service_evidence/infrastructure/http_evidence_repository.dart';
import 'package:http/http.dart' as http;

import 'core/http/authorized_http.dart';
import 'features/company/applications/application/company_repositories.dart';
import 'features/company/applications/infrastructure/http_company_application_repository.dart';
import 'features/company/applications/infrastructure/http_company_opportunities_repository.dart';
import 'features/client/profile/application/ports/client_profile_repository.dart';
import 'features/client/profile/infrastructure/http_client_profile_repository.dart';
import 'features/client/service_requests/application/ports/service_request_repository.dart';
import 'features/client/service_requests/infrastructure/http_service_request_repository.dart';
import 'features/client/service_requests/infrastructure/http_compatible_technicians_repository.dart';
import 'features/contracts/application/ports/contract_repository.dart';
import 'features/contracts/infrastructure/http_contract_repository.dart';
import 'features/quotations/application/ports/quotation_repository.dart';
import 'features/quotations/infrastructure/http_quotation_repository.dart';
import 'features/service_history/application/ports/service_history_repository.dart';
import 'features/service_history/infrastructure/http_service_history_repository.dart';
import 'features/technician/applications/application/ports/application_repository.dart';
import 'features/technician/applications/infrastructure/http_application_repository.dart';
import 'features/technician/opportunities/application/ports/opportunity_repository.dart';
import 'features/technician/opportunities/infrastructure/http_opportunity_repository.dart';
import 'features/technician/availability/application/ports/technician_availability_repository.dart';
import 'features/payments/infrastructure/http_payments_repository.dart';
import 'features/technician/availability/infrastructure/http_technician_availability_repository.dart';

/// Repositorios que conectan las pantallas con ms-users y ms-services
/// (GC-320, GC-335, GC-340, GC-345, GC-426, GC-428, GC-429). Si la app no los recibe, esas pantallas
/// funcionan con datos de demostración (pruebas de widgets).
class BackendIntegrations {
  const BackendIntegrations({
    required this.clientProfile,
    required this.serviceRequests,
    required this.opportunities,
    required this.applications,
    required this.quotations,
    required this.contracts,
    this.evidence,
    this.companyApplications,
    this.companyOpportunities,
    this.technicianAvailability,
    this.compatibleTechnicians,
    this.payments,
    this.serviceHistory,
    this.evaluations,
  });

  /// Todos comparten un solo [AuthorizedHttp]: si varias llamadas reciben
  /// 401 a la vez, la sesión se renueva una sola vez.
  factory BackendIntegrations.http({
    required http.Client client,
    required Uri usersBaseUrl,
    required Uri servicesBaseUrl,
    Uri? paymentsBaseUrl,
    required AuthorizedHttp authorizedHttp,
  }) {
    final contracts = HttpContractRepository(
        client: client,
        baseUrl: servicesBaseUrl,
        authorizedHttp: authorizedHttp);
    return BackendIntegrations(
      evidence: EvidenceFeature(
          contracts: contracts,
          repositoryFor: (access) => HttpEvidenceRepository(
              client: client,
              baseUrl: servicesBaseUrl,
              authorizedHttp: authorizedHttp,
              access: access)),
      companyApplications: HttpCompanyApplicationRepository(
          client: client,
          baseUrl: servicesBaseUrl,
          authorizedHttp: authorizedHttp),
      companyOpportunities: HttpCompanyOpportunitiesRepository(
          client: client,
          baseUrl: servicesBaseUrl,
          authorizedHttp: authorizedHttp),
      clientProfile: HttpClientProfileRepository(
        client: client,
        baseUrl: usersBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      serviceRequests: HttpServiceRequestRepository(
        client: client,
        baseUrl: servicesBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      opportunities: HttpOpportunityRepository(
        client: client,
        baseUrl: servicesBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      applications: HttpApplicationRepository(
        client: client,
        baseUrl: servicesBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      quotations: HttpQuotationRepository(
        client: client,
        baseUrl: servicesBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      contracts: contracts,
      payments: HttpPaymentsRepository(
        client: client,
        baseUrl: paymentsBaseUrl ?? servicesBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      compatibleTechnicians: HttpCompatibleTechniciansRepository(
        client: client,
        baseUrl: servicesBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      technicianAvailability: HttpTechnicianAvailabilityRepository(
        client: client,
        baseUrl: usersBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      serviceHistory: HttpServiceHistoryRepository(
        client: client,
        baseUrl: servicesBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
      evaluations: HttpServiceEvaluationRepository(
        client: client,
        baseUrl: usersBaseUrl,
        authorizedHttp: authorizedHttp,
      ),
    );
  }

  final EvidenceFeature? evidence;
  final ClientProfileRepository clientProfile;
  final ServiceRequestRepository serviceRequests;
  final OpportunityRepository opportunities;
  final ApplicationRepository applications;

  /// Cotizaciones y contrataciones (GC-428, GC-429).
  final QuotationRepository quotations;
  final ContractRepository contracts;
  final CompanyApplicationRepository? companyApplications;
  final CompanyOpportunitiesRepository? companyOpportunities;

  /// Horario y zona de atención del técnico (GC-329, GC-330).
  final TechnicianAvailabilityRepository? technicianAvailability;

  /// Técnicos compatibles con una solicitud del cliente (GC-474).
  final HttpCompatibleTechniciansRepository? compatibleTechnicians;

  /// Billetera y pagos simulados con ms-payments (GC-489, GC-491).
  final HttpPaymentsRepository? payments;

  /// Historial propio y evaluaciones (GC-449). Si faltan, «Mis servicios»
  /// pide conexión en vez de mostrar datos de ejemplo.
  final ServiceHistoryRepository? serviceHistory;
  final ServiceEvaluationRepository? evaluations;
}
