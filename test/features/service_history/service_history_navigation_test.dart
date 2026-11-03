import 'package:ms_frontend/features/client/service_requests/presentation/my_service_requests_page.dart';
import 'package:ms_frontend/features/payments/presentation/service_payment_panel.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/contracts/application/ports/contract_repository.dart';
import 'package:ms_frontend/features/contracts/infrastructure/http_contract_repository.dart';
import 'package:ms_frontend/features/payments/infrastructure/http_payments_repository.dart';
import '../payments/closure_payment_flow_test.dart' show contractJson;
import '../payments/payment_repository_test.dart'
    show walletPaymentJson, response;
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
  ContractRepository? contracts,
  HttpPaymentsRepository? payments,
  ServiceRequestRepository? requests,
  bool withHistory = true,
}) async {
  tester.view.physicalSize = const Size(1024, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    FixiaApp(
      backend: BackendIntegrations(
        clientProfile: _Profiles(),
        serviceRequests: requests ?? _Requests(),
        opportunities: _Opportunities(),
        applications: _Applications(),
        quotations: FakeQuotations(),
        contracts: contracts ?? FakeContracts(),
        payments: payments,
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
  for (final (lostResponse, recharge, fromRequests) in [
    (false, false, false),
    (true, false, false),
    (false, true, false),
    (false, false, true)
  ]) {
    testWidgets(
        'historial cierra una vez y consulta pago; respuesta perdida=$lostResponse recarga=$recharge solicitudes=$fromRequests',
        (tester) async {
      var state = 'TECHNICIAN_FINISHED';
      var paymentState = recharge ? 'Failed' : 'Processing';
      var balance = 0.0;
      final calls = <String>[];
      final closure = Completer<http.Response>();
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/entries')) {
          return response({'items': [], 'nextCursor': null});
        }
        if (request.method == 'POST' && request.url.path.endsWith('/top-ups')) {
          expectSync(request.headers['Idempotency-Key'], isNotEmpty);
          balance = 50000;
          return response({
            'availableBalance': balance,
            'heldBalance': 0,
            'currency': 'COP'
          }, 201);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/process')) {
          expectSync(paymentState, 'Failed');
          paymentState = 'Processing';
          return response(walletPaymentJson(status: paymentState));
        }
        if (request.method == 'POST') {
          expectSync(request.url.path, '/api/services/requests/req-1/closure');
          expectSync(request.body, isEmpty);
          state = 'CLOSED';
          return closure.future;
        }
        if (request.url.path.endsWith('/contract')) {
          return response(contractJson(state));
        }
        if (request.url.path.endsWith('/wallets/me')) {
          return response({
            'availableBalance': balance,
            'heldBalance': 1150.5,
            'currency': 'COP'
          });
        }
        expectSync(
            request.url.path,
            anyOf(
                '/api/payments/service-request/req-1', '/api/payments/pay-1'));
        return response(walletPaymentJson(status: paymentState));
      });
      addTearDown(client.close);
      final auth = AuthorizedHttp(
          accessToken: () => 'token', renewSession: () async => false);
      final history = FakeServiceHistory({
        null: ServiceHistoryResult(items: [
          historyEntry('1', status: ServiceRequestStatus.technicianFinished)
        ])
      });
      final requests = _Requests(
          load: () => ServiceRequest(
              id: 'req-1',
              category: ServiceCategory.plumbing,
              description: 'Fuga de agua',
              status: state == 'CLOSED'
                  ? ServiceRequestStatus.closed
                  : ServiceRequestStatus.technicianFinished,
              approximateLocation:
                  const ApproximateLocation(city: 'Bogotá', zone: 'Centro'),
              expectedAt: DateTime.utc(2027)));
      await _pumpApp(tester,
          requests: requests,
          profile: fixtureProfile,
          history: history,
          evaluations: FakeEvaluations([
            evaluation('req-1', by: fixtureProfile.id, to: technicianUserId)
          ]),
          contracts: HttpContractRepository(
              client: client,
              baseUrl: Uri.parse('http://gateway'),
              authorizedHttp: auth),
          payments: HttpPaymentsRepository(
              client: client,
              baseUrl: Uri.parse('http://gateway'),
              authorizedHttp: auth));
      _navigator(tester).pushNamed(AppRoutes.clientDashboard);
      await tester.pumpAndSettle();
      if (fromRequests) {
        await tester.tap(_key('client-nav-historial'));
        await tester.pumpAndSettle();
        final page = tester
            .widget<MyServiceRequestsPage>(find.byType(MyServiceRequestsPage));
        unawaited(page.onOpen!(await requests.getMine('req-1')));
        await tester.pumpAndSettle();
      } else {
        await tester.tap(_key('client-nav-servicios'));
        await tester.pumpAndSettle();
        await tester.tap(_key('service-history-con-1'));
        await tester.pumpAndSettle();
      }
      if (recharge) {
        expect(find.text('Retención fallida'), findsOneWidget);
        await tester.ensureVisible(find.text('Recargar saldo'));
        await tester.tap(find.text('Recargar saldo'));
        await tester.pumpAndSettle();
        expect(_key('wallet-operate'), findsOneWidget);
        await tester.tap(_key('wallet-operate'));
        await tester.pumpAndSettle();
        await tester.tap(_key('wallet-quick-50000'));
        await tester.tap(_key('wallet-amount-confirm'));
        await tester.pumpAndSettle();
        expect(_key('wallet-operation-done'), findsOneWidget);
        _navigator(tester).pop();
        await tester.pumpAndSettle();
        expect(find.text('Retención fallida'), findsOneWidget);
        expect(calls.where((c) => c.endsWith('/process')), isEmpty);
        await tester.ensureVisible(find.text('Reintentar retención'));
        await tester.tap(find.text('Reintentar retención'));
        await tester.pumpAndSettle();
        expect(
            calls.where((c) => c == 'GET /api/payments/pay-1'), hasLength(1));
        expect(calls.where((c) => c == 'POST /api/payments/pay-1/process'),
            hasLength(1));
      }
      expect(find.text('Pago retenido'), findsOneWidget);
      if (!fromRequests) expect(find.text('Tu evaluación'), findsOneWidget);
      final initialReads = calls
          .where((c) => c == 'GET /api/payments/service-request/req-1')
          .length;
      expect(initialReads, recharge ? 3 : 1);
      final action = tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar y pagar'))
          .onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      final confirm = tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar y pagar').last)
          .onPressed!;
      confirm();
      confirm();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
          calls.where((c) => c == 'POST /api/services/requests/req-1/closure'),
          hasLength(1));
      expect(state, 'CLOSED');
      if (lostResponse) {
        closure.completeError(http.ClientException('respuesta perdida'));
      } else {
        closure.complete(response(contractJson(state)));
      }
      await tester.pumpAndSettle();
      expect(find.text('Confirmar y pagar'), findsNothing);
      expect(
          find.descendant(
              of: find.byType(ServicePaymentPanel),
              matching: find.text('Servicio cerrado.')),
          findsOneWidget);
      expect(find.text('Pago retenido'), findsOneWidget);
      expect(find.text('Pago completado'), findsNothing);
      expect(
          calls
              .where((c) => c == 'GET /api/payments/service-request/req-1')
              .length,
          greaterThan(initialReads));
      paymentState = 'Completed';
      await tester.ensureVisible(find.text('Actualizar pago'));
      await tester.tap(find.text('Actualizar pago'));
      await tester.pumpAndSettle();
      expect(find.text('Pago completado'), findsOneWidget);
      expect(find.text('Retención cobrada'), findsOneWidget);
      expect(find.text('Pago retenido'), findsNothing);
      if (!fromRequests) expect(find.text('Tu evaluación'), findsOneWidget);
      expect(calls.where((c) => c.startsWith('POST')).toList(), [
        if (recharge) ...[
          'POST /api/payments/wallets/me/top-ups',
          'POST /api/payments/pay-1/process'
        ],
        'POST /api/services/requests/req-1/closure'
      ]);
      await tester.ensureVisible(_key('page-back'));
      await tester.tap(_key('page-back'));
      await tester.pumpAndSettle();
      if (fromRequests) {
        expect(find.byType(MyServiceRequestsPage), findsOneWidget);
      } else {
        expect(find.byType(ServiceHistoryPage), findsOneWidget);
        expect(history.requestedCursors.length, greaterThan(1));
      }
    });
  }

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
  _Requests({this.load});
  final ServiceRequest Function()? load;
  @override
  Future<List<ServiceRequest>> listMine() async =>
      load == null ? const [] : [load!()];

  @override
  Future<ServiceRequest> publish(NewServiceRequest request) =>
      throw UnimplementedError();

  @override
  Future<ServiceRequest> getMine(String id) async => load!();

  @override
  Future<List<Applicant>> listApplicants(String requestId) async => const [];

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
