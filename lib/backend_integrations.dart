import 'package:http/http.dart' as http;

import 'core/http/authorized_http.dart';
import 'features/client/profile/application/ports/client_profile_repository.dart';
import 'features/client/profile/infrastructure/http_client_profile_repository.dart';
import 'features/client/service_requests/application/ports/service_request_repository.dart';
import 'features/client/service_requests/infrastructure/http_service_request_repository.dart';
import 'features/technician/applications/application/ports/application_repository.dart';
import 'features/technician/applications/infrastructure/http_application_repository.dart';
import 'features/technician/opportunities/application/ports/opportunity_repository.dart';
import 'features/technician/opportunities/infrastructure/http_opportunity_repository.dart';

/// Repositorios que conectan las pantallas con ms-users y ms-services
/// (GC-320, GC-335, GC-340, GC-345). Si la app no los recibe, esas pantallas
/// funcionan con datos de demostración (pruebas de widgets).
class BackendIntegrations {
  const BackendIntegrations({
    required this.clientProfile,
    required this.serviceRequests,
    required this.opportunities,
    required this.applications,
  });

  /// Todos comparten un solo [AuthorizedHttp]: si varias llamadas reciben
  /// 401 a la vez, la sesión se renueva una sola vez.
  factory BackendIntegrations.http({
    required http.Client client,
    required Uri usersBaseUrl,
    required Uri servicesBaseUrl,
    required AuthorizedHttp authorizedHttp,
  }) =>
      BackendIntegrations(
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
      );

  final ClientProfileRepository clientProfile;
  final ServiceRequestRepository serviceRequests;
  final OpportunityRepository opportunities;
  final ApplicationRepository applications;
}
