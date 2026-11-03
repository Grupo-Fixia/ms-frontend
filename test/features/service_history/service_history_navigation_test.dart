import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/backend_integrations.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/client/profile/application/ports/client_profile_repository.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_update.dart';
import 'package:ms_frontend/features/client/service_requests/application/ports/service_request_repository.dart';
import 'package:ms_frontend/features/client/service_requests/domain/applicant.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_entry.dart';
import 'package:ms_frontend/features/service_history/presentation/service_history_page.dart';
import 'package:ms_frontend/features/technician/applications/application/ports/application_repository.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';
import 'package:ms_frontend/features/technician/opportunities/application/ports/opportunity_repository.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity.dart';
import 'package:ms_frontend/main.dart';

import '../auth/login/fake_auth_repository.dart';
import '../auth/registration/fake_repository.dart';
import '../service_flow_fakes.dart';
import '../technician/profile/fake_repository.dart';
import '../technician/profile/fixtures.dart';
import 'fake_service_history.dart';

const _technician = UserProfile(
  id: technicianUserId,
  email: 'tecnico1@fixia-qa.test',
  firstName: 'Carlos',
  lastName: 'Giraldo',
  role: UserRole.professional,
);

ServiceContract _contract(ServiceHistoryEntry entry) => ServiceContract(
      id: entry.contractId,
      serviceRequestId: entry.serviceRequestId,
      quotationId: 'quo-1',
      clientId: clientUserId,
      providerId: technicianUserId,
      amountInCents: 18000000,
      currency: 'COP',
      scope: 'Cambiar el empaque del lavaplatos',
      conditions: 'Incluye materiales',
      agreedAt: DateTime.utc(2026, 10, 28, 15),
      contractedAt: DateTime.utc(2026, 10, 25, 14),
      request: const ContractedRequest(
        category: ServiceCategory.plumbing,
        description: 'Fuga en la cocina',
        city: 'Bogotá',
        zone: 'Chapinero',
      ),
      serviceStatus: entry.status,
      timeline: [
        ContractTransition(
          toStatus: ServiceRequestStatus.closed,
          fromStatus: ServiceRequestStatus.technicianFinished,
          actor: TransitionActor.client,
          occurredAt: DateTime.utc(2026, 10, 30, 18),
        ),
      ],
    );

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _pumpApp(
  WidgetTester tester, {
  required UserProfile profile,
  FakeServiceHistory? history,
  FakeEvaluations? evaluations,
  FakeContracts? contracts,
  bool withHistory = true,
}) async {
  tester.view.physicalSize = const Size(1024, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    FixiaApp(
      backend: BackendIntegrations(
        clientProfile: _Profiles(),
        serviceRequests: _Requests(),
        opportunities: _Opportunities(),
        applications: _Applications(),
        quotations: FakeQuotations(),
        contracts: contracts ?? FakeContracts(),
        serviceHistory: withHistory ? history ?? FakeServiceHistory({}) : null,
        evaluations: withHistory ? evaluations ?? FakeEvaluations() : null,
      ),
      clientRegistrationRepository: FakeAccountRegistrationRepository(),
      technicianRegistrationRepository: FakeAccountRegistrationRepository(),
      technicianProfileRepository:
          FakeTechnicianProfileRepository(profile: emptyProfile),
      authRepository: FakeAuthRepository(profile: profile),
      sessionStorage: FakeSessionStorage(),
      sessionStore: SessionStore()..start(fixtureSession, profile),
    ),
  );
  await tester.pumpAndSettle();
}

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

void main() {
  testWidgets(
      'el cliente entra desde el menú, ve su historial y abre el detalle '
      'con contrato e historial de cambios', (tester) async {
    final closed = historyEntry('3', closedAt: DateTime.utc(2026, 10, 30, 18));
    final contracts = FakeContracts()..items.add(_contract(closed));
    await _pumpApp(
      tester,
      profile: fixtureProfile,
      history: FakeServiceHistory({
        null: ServiceHistoryResult(items: [closed]),
      }),
      evaluations: FakeEvaluations([
        evaluation('req-3', by: fixtureProfile.id, to: technicianUserId),
      ]),
      contracts: contracts,
    );
    _navigator(tester).pushNamed(AppRoutes.clientDashboard);
    await tester.pumpAndSettle();

    await tester.tap(_key('client-nav-servicios'));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceHistoryPage), findsOneWidget);
    expect(_key('service-history-con-3'), findsOneWidget);

    await tester.tap(_key('service-history-con-3'));
    await tester.pumpAndSettle();

    expect(find.text('Tu contratación'), findsOneWidget);
    expect(find.text('Incluye materiales'), findsOneWidget);
    expect(find.text('Tu evaluación'), findsOneWidget);
  });

  testWidgets('el técnico entra desde el menú y abre su contratación',
      (tester) async {
    final closed = historyEntry('3', role: HistoryRole.professional);
    final contracts = FakeContracts()..items.add(_contract(closed));
    await _pumpApp(
      tester,
      profile: _technician,
      history: FakeServiceHistory({
        null: ServiceHistoryResult(items: [closed]),
      }),
      contracts: contracts,
    );
    _navigator(tester).pushNamed(AppRoutes.technicianDashboard);
    await tester.pumpAndSettle();

    await tester.tap(_key('technician-nav-servicios'));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceHistoryPage), findsOneWidget);
    expect(find.text('Como técnico'), findsOneWidget);

    await tester.tap(_key('service-history-con-3'));
    await tester.pumpAndSettle();

    expect(find.text('Contratación'), findsWidgets);
    expect(find.text('Cambiar el empaque del lavaplatos'), findsOneWidget);
    expect(find.text('Este servicio todavía no tiene evaluaciones.'),
        findsOneWidget);

    await tester.tap(_key('page-back'));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceHistoryPage), findsOneWidget);
  });

  testWidgets('cada rol solo abre su ruta de historial', (tester) async {
    await _pumpApp(tester, profile: fixtureProfile);
    _navigator(tester).pushNamed(AppRoutes.technicianServiceHistory);
    await tester.pumpAndSettle();
    expect(find.byType(ServiceHistoryPage), findsNothing);
    expect(_key('client-dashboard-greeting'), findsOneWidget);
  });

  testWidgets('la empresa no tiene historial de servicios', (tester) async {
    await _pumpApp(
      tester,
      profile: const UserProfile(
        id: 'c0a00000-0000-4000-8000-000000000001',
        email: 'empresa1@fixia-qa.test',
        firstName: 'Laura',
        lastName: 'Gómez',
        role: UserRole.company,
      ),
    );
    _navigator(tester).pushNamed(AppRoutes.clientServiceHistory);
    await tester.pumpAndSettle();

    expect(find.byType(ServiceHistoryPage), findsNothing);
  });

  testWidgets('sin el historial conectado, la sección lo avisa',
      (tester) async {
    await _pumpApp(tester, profile: fixtureProfile, withHistory: false);
    _navigator(tester).pushNamed(AppRoutes.clientServiceHistory);
    await tester.pumpAndSettle();
    expect(find.textContaining('requiere conexión'), findsOneWidget);
  });
}

class _Profiles implements ClientProfileRepository {
  @override
  Future<ClientProfile> fetchProfile() => throw UnimplementedError();

  @override
  Future<ClientProfile> updateProfile(ClientProfileUpdate update) =>
      throw UnimplementedError();
}

class _Requests implements ServiceRequestRepository {
  @override
  Future<List<ServiceRequest>> listMine() async => const [];

  @override
  Future<ServiceRequest> publish(NewServiceRequest request) =>
      throw UnimplementedError();

  @override
  Future<ServiceRequest> getMine(String id) => throw UnimplementedError();

  @override
  Future<List<Applicant>> listApplicants(String requestId) =>
      throw UnimplementedError();

  @override
  Future<ServiceRequest> selectProvider(
          String requestId, String applicationId) =>
      throw UnimplementedError();
}

class _Opportunities implements OpportunityRepository {
  @override
  Future<OpportunityPage> fetchPage(
          {required int limit, String? cursor}) async =>
      const OpportunityPage(items: []);
}

class _Applications implements ApplicationRepository {
  @override
  Future<List<ServiceApplication>> listMine() async => const [];

  @override
  Future<ServiceApplication> apply(String serviceRequestId,
          {ProposedPrice? proposedPrice}) =>
      throw UnimplementedError();

  @override
  Future<ServiceApplication> getMine(String id) => throw UnimplementedError();
}
