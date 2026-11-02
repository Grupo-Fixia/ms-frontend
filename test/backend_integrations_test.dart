import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/backend_integrations.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/client/profile/infrastructure/http_client_profile_repository.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/http_service_request_repository.dart';
import 'package:ms_frontend/features/technician/applications/infrastructure/http_application_repository.dart';
import 'package:ms_frontend/features/technician/opportunities/infrastructure/http_opportunity_repository.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/client/profile/application/ports/client_profile_repository.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_exceptions.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_update.dart';
import 'package:ms_frontend/features/client/service_requests/application/ports/service_request_repository.dart';
import 'package:ms_frontend/features/client/service_requests/domain/applicant.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/technician/applications/application/ports/application_repository.dart';
import 'package:ms_frontend/features/technician/applications/domain/application_exceptions.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';
import 'package:ms_frontend/features/technician/opportunities/application/ports/opportunity_repository.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity_exceptions.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';
import 'features/service_flow_fakes.dart';
import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

/// Las pantallas de perfil del cliente, publicar solicitud, oportunidades y
/// postulación usan el backend real (GC-320, GC-335, GC-340, GC-345).

const _technician = UserProfile(
  id: 'usr-tec',
  email: 'tecnico@fixia.com',
  firstName: 'Tomás',
  lastName: 'Rojas',
  role: UserRole.professional,
);

class _Profiles implements ClientProfileRepository {
  ClientProfileUpdate? saved;
  Object? failure;
  Object? fetchFailure;
  ClientProfile? stored;

  @override
  Future<ClientProfile> fetchProfile() async {
    if (fetchFailure != null) throw fetchFailure!;
    return stored ?? (throw StateError('sin perfil guardado'));
  }

  @override
  Future<ClientProfile> updateProfile(ClientProfileUpdate update) async {
    if (failure != null) throw failure!;
    saved = update;
    return ClientProfile(
      id: 'cli',
      email: 'ana@fixia.com',
      firstName: update.firstName,
      lastName: update.lastName,
      phone: update.phone,
    );
  }
}

class _Requests implements ServiceRequestRepository {
  NewServiceRequest? published;
  Object? failure;

  @override
  Future<ServiceRequest> publish(NewServiceRequest request) async {
    if (failure != null) throw failure!;
    published = request;
    return ServiceRequest(
      id: 'sr-1',
      category: request.category!,
      description: request.description,
      status: ServiceRequestStatus.published,
      approximateLocation: request.approximateLocation,
      expectedAt: request.expectedAt!,
      budget: request.budget,
    );
  }

  @override
  Future<List<ServiceRequest>> listMine() => throw UnimplementedError();

  @override
  Future<ServiceRequest> getMine(String id) => throw UnimplementedError();

  @override
  Future<List<Applicant>> listApplicants(String requestId) =>
      throw UnimplementedError();

  @override
  Future<ServiceRequest> selectProvider(
    String requestId,
    String applicationId,
  ) =>
      throw UnimplementedError();
}

class _Opportunities implements OpportunityRepository {
  _Opportunities(this.items);

  List<Opportunity> items;
  Object? failure;
  int calls = 0;

  @override
  Future<OpportunityPage> fetchPage(
      {required int limit, String? cursor}) async {
    calls++;
    if (failure != null) throw failure!;
    return OpportunityPage(items: items);
  }
}

class _Applications implements ApplicationRepository {
  final applied = <String>[];
  final saved = <ServiceApplication>[];
  ProposedPrice? price;
  Object? failure;

  @override
  Future<ServiceApplication> apply(String serviceRequestId,
      {ProposedPrice? proposedPrice}) async {
    if (failure != null) throw failure!;
    applied.add(serviceRequestId);
    price = proposedPrice;
    final result = ServiceApplication(
      id: 'app-1',
      proposedPrice: proposedPrice,
      status: ApplicationStatus.applied,
      serviceRequest: ApplicationRequestSummary(
        id: serviceRequestId,
        category: ServiceCategory.plumbing,
        city: 'Bogotá',
        zone: 'Chapinero',
      ),
    );
    saved.add(result);
    return result;
  }

  @override
  Future<List<ServiceApplication>> listMine() async => List.unmodifiable(saved);

  @override
  Future<ServiceApplication> getMine(String id) => throw UnimplementedError();
}

final _leak = Opportunity(
  id: 'sr-leak',
  category: ServiceCategory.plumbing,
  description: 'Fuga en el baño principal',
  city: 'Bogotá',
  zone: 'Chapinero',
  expectedAt: DateTime(2026, 11, 3, 9, 30),
  publishedAt: DateTime.now().subtract(const Duration(minutes: 7)),
);

void main() {
  test('la app real conecta cada pantalla con su servicio', () {
    final backend = BackendIntegrations.http(
      client: MockClient((_) async => http.Response('', 404)),
      usersBaseUrl: Uri.parse('http://localhost'),
      servicesBaseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => null,
        renewSession: () async => false,
      ),
    );

    expect(backend.clientProfile, isA<HttpClientProfileRepository>());
    expect(backend.serviceRequests, isA<HttpServiceRequestRepository>());
    expect(backend.opportunities, isA<HttpOpportunityRepository>());
    expect(backend.applications, isA<HttpApplicationRepository>());
  });

  late _Profiles profiles;
  late _Requests requests;
  late _Opportunities opportunities;
  late _Applications applications;

  setUp(() {
    profiles = _Profiles();
    requests = _Requests();
    opportunities = _Opportunities([_leak]);
    applications = _Applications();
  });

  Future<SessionStore> pump(
    WidgetTester tester,
    UserProfile profile,
    String route,
  ) async {
    tester.view.physicalSize = const Size(1024, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = SessionStore()..start(fixtureSession, profile);
    await tester.pumpWidget(
      FixiaApp(
        backend: BackendIntegrations(
          clientProfile: profiles,
          serviceRequests: requests,
          opportunities: opportunities,
          applications: applications,
          quotations: FakeQuotations(),
          contracts: FakeContracts(),
        ),
        clientRegistrationRepository: FakeAccountRegistrationRepository(),
        technicianRegistrationRepository: FakeAccountRegistrationRepository(),
        technicianProfileRepository:
            FakeTechnicianProfileRepository(profile: emptyProfile),
        authRepository: FakeAuthRepository(),
        sessionStorage: FakeSessionStorage(),
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
    await tester.pumpAndSettle();
    return store;
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('GC-320 perfil del cliente', () {
    Future<void> editAndSave(WidgetTester tester) async {
      await tester.tap(key('client-profile-edit'));
      await tester.pumpAndSettle();
      await tester.enterText(key('client-profile-first-name'), 'Ana María');
      await tester.enterText(key('client-profile-phone'), '3001234567');
      await tester.ensureVisible(key('client-profile-save'));
      await tester.tap(key('client-profile-save'));
      await tester.pumpAndSettle();
    }

    testWidgets('guarda en el servidor y actualiza la sesión', (tester) async {
      final store = await pump(tester, fixtureProfile, AppRoutes.clientProfile);

      await editAndSave(tester);

      expect(profiles.saved?.firstName, 'Ana María');
      expect(profiles.saved?.phone, '3001234567');
      expect(store.profile?.firstName, 'Ana María');
      expect(key('client-profile-saved'), findsOneWidget);
      expect(key('client-profile-saved-local'), findsNothing,
          reason: 'ya no es un guardado de prueba');
    });

    testWidgets('si el servidor rechaza, avisa y no cambia la sesión',
        (tester) async {
      profiles.failure = const ClientProfileFailure(
        'Revisa los datos marcados.',
        fieldErrors: {'phone': 'El teléfono no es válido.'},
      );
      final store = await pump(tester, fixtureProfile, AppRoutes.clientProfile);

      await editAndSave(tester);

      expect(find.text('El teléfono no es válido.'), findsOneWidget);
      expect(store.profile?.firstName, fixtureProfile.firstName);
      expect(key('client-profile-form'), findsOneWidget,
          reason: 'sigue editando');
    });

    testWidgets(
        'carga del servidor el teléfono que la sesión no trae y deja guardar '
        'sin volver a escribirlo', (tester) async {
      profiles.stored = const ClientProfile(
        id: 'cli',
        email: 'ana@fixia.com',
        firstName: 'Ana',
        lastName: 'Pérez',
        phone: '3009998877',
      );
      await pump(
        tester,
        fixtureProfile.copyWith(phone: ''),
        AppRoutes.clientProfile,
      );
      expect(find.text('3009998877'), findsOneWidget);

      await tester.tap(key('client-profile-edit'));
      await tester.pumpAndSettle();
      await tester.enterText(key('client-profile-first-name'), 'Ana María');
      await tester.ensureVisible(key('client-profile-save'));
      await tester.tap(key('client-profile-save'));
      await tester.pumpAndSettle();

      expect(profiles.saved?.phone, '3009998877');
      expect(profiles.saved?.firstName, 'Ana María');
      expect(find.textContaining('/16'), findsNothing,
          reason: 'sin el contador de 16 que confundía');
    });

    testWidgets('si la sesión venció al cargar el perfil, lleva al login',
        (tester) async {
      profiles.fetchFailure =
          const ClientProfileFailure('Sesión vencida', isSessionExpired: true);

      final store = await pump(tester, fixtureProfile, AppRoutes.clientProfile);

      expect(store.isAuthenticated, isFalse);
      expect(key('login-submit'), findsOneWidget);
    });

    testWidgets('si la sesión venció, lleva al login', (tester) async {
      profiles.failure =
          const ClientProfileFailure('Sesión vencida', isSessionExpired: true);
      final store = await pump(tester, fixtureProfile, AppRoutes.clientProfile);

      await editAndSave(tester);

      expect(store.isAuthenticated, isFalse);
      expect(key('login-submit'), findsOneWidget);
    });
  });

  group('GC-335 publicar solicitud', () {
    Future<void> fillForm(WidgetTester tester, {bool location = true}) async {
      await tester.tap(key('client-request-category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceCategory.plumbing.label).last);
      await tester.pumpAndSettle();
      await tester.enterText(
          key('client-request-description'), 'Fuga en el lavaplatos');
      await scrollTo(tester, key('client-request-budget'));
      await tester.enterText(key('client-request-budget'), '150000');
      if (location) {
        await scrollTo(tester, key('client-request-change-location'));
        await tester.tap(key('client-request-change-location'));
        await tester.pumpAndSettle();
        await tester.enterText(key('client-request-city'), ' Bogotá ');
        await tester.enterText(key('client-request-zone'), 'Chapinero');
        await tester.tap(key('client-request-location-save'));
        await tester.pumpAndSettle();
      }
      await scrollTo(tester, key('client-request-expected-at'));
      await tester.tap(key('client-request-expected-at'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      // Mañana, para que siempre sea un momento futuro.
      final tomorrow = now.add(const Duration(days: 1));
      if (tomorrow.month != now.month) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('${tomorrow.day}').last);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
    }

    testWidgets('la ubicación es obligatoria antes de enviar', (tester) async {
      await pump(tester, fixtureProfile, AppRoutes.clientServiceRequest);

      await fillForm(tester, location: false);

      await scrollTo(tester, key('client-request-submit'));
      final submit =
          tester.widget<ButtonStyleButton>(key('client-request-submit'));
      expect(submit.onPressed, isNull);
      expect(find.textContaining('Elige tu ciudad'), findsOneWidget);
    });

    testWidgets('la ubicación pide ciudad y barrio, y se puede cancelar',
        (tester) async {
      await pump(tester, fixtureProfile, AppRoutes.clientServiceRequest);

      await tester.tap(key('client-request-change-location'));
      await tester.pumpAndSettle();
      await tester.tap(key('client-request-location-save'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe la ciudad.'), findsOneWidget);
      expect(find.text('Escribe el barrio o localidad.'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(key('client-request-location-dialog'), findsNothing);
      expect(find.textContaining('Elige tu ciudad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('publica en el servidor con la ubicación elegida',
        (tester) async {
      await pump(tester, fixtureProfile, AppRoutes.clientServiceRequest);
      await fillForm(tester);
      expect(find.textContaining('Chapinero, Bogotá'), findsOneWidget);

      await scrollTo(tester, key('client-request-submit'));
      await tester.tap(key('client-request-submit'));
      await tester.pumpAndSettle();

      final sent = requests.published!;
      expect(sent.category, ServiceCategory.plumbing);
      expect(sent.description, 'Fuga en el lavaplatos');
      expect(sent.approximateLocation.city, 'Bogotá');
      expect(sent.approximateLocation.zone, 'Chapinero');
      expect(sent.photoKeys, isEmpty);
      expect(sent.budget!.amount, '150000');
      expect(find.text('Solicitud publicada'), findsOneWidget);
      expect(find.textContaining('demostración'), findsNothing);

      await tester.tap(key('client-request-confirmation-close'));
      await tester.pumpAndSettle();
      expect(key('client-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza, muestra el motivo y no confirma',
        (tester) async {
      requests.failure = const ServiceRequestFailure(
        'Revisa los datos marcados.',
        fieldErrors: {'expectedAt': 'El momento esperado debe ser futuro.'},
      );
      await pump(tester, fixtureProfile, AppRoutes.clientServiceRequest);
      await fillForm(tester);

      await scrollTo(tester, key('client-request-submit'));
      await tester.tap(key('client-request-submit'));
      await tester.pumpAndSettle();

      expect(find.text('El momento esperado debe ser futuro.'), findsOneWidget);
      expect(find.text('Solicitud publicada'), findsNothing);
      await scrollTo(tester, key('client-request-budget'));
      expect(
        tester
            .widget<TextFormField>(key('client-request-budget'))
            .controller!
            .text,
        '150000',
        reason: 'un error no borra el presupuesto escrito',
      );
    });
  });

  group('GC-340 y GC-345 oportunidades y postulación', () {
    testWidgets('muestra las solicitudes compatibles del servidor',
        (tester) async {
      await pump(tester, _technician, AppRoutes.technicianOpportunities);

      expect(opportunities.calls, 1);
      expect(key('technician-opportunity-sr-leak'), findsOneWidget);
      expect(find.text('Fuga en el baño principal'), findsOneWidget);
      expect(find.textContaining('Chapinero, Bogotá'), findsWidgets);
      expect(find.text('1 solicitudes'), findsOneWidget);
      expect(find.textContaining('de ejemplo'), findsNothing);
    });

    testWidgets('sin solicitudes compatibles lo dice', (tester) async {
      opportunities.items = [];
      await pump(tester, _technician, AppRoutes.technicianOpportunities);

      expect(find.text('Por ahora no hay solicitudes compatibles contigo.'),
          findsOneWidget);
    });

    testWidgets('si falla la consulta, muestra el error y permite reintentar',
        (tester) async {
      opportunities.failure =
          const OpportunityFailure('No pudimos cargar las solicitudes.');
      await pump(tester, _technician, AppRoutes.technicianOpportunities);
      expect(key('technician-opportunities-error'), findsOneWidget);

      opportunities.failure = null;
      await tester.tap(key('technician-opportunities-retry'));
      await tester.pumpAndSettle();

      expect(find.text('Fuga en el baño principal'), findsOneWidget);
    });

    Future<void> applyTo(WidgetTester tester) async {
      final detail = key('technician-opportunity-detail-sr-leak');
      await tester.ensureVisible(detail);
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(find.text('Fuga en el baño principal'), findsWidgets);
      expect(find.textContaining('Demostración local'), findsNothing);
      final price = key('application-price');
      await tester.ensureVisible(price);
      await tester.enterText(price, '150000');
      await tester.ensureVisible(key('application-price-submit'));
      await tester.tap(key('application-price-submit'));
      await tester.pumpAndSettle();
    }

    testWidgets('se postula en el servidor', (tester) async {
      await pump(tester, _technician, AppRoutes.technicianOpportunities);

      await applyTo(tester);

      expect(applications.applied, ['sr-leak']);
      expect(applications.price?.amount, '150000');
      expect(key('technician-apply-done'), findsOneWidget);
    });

    testWidgets(
        'precio confirmado se recupera al consultar y refrescar postulaciones',
        (tester) async {
      await pump(tester, _technician, AppRoutes.technicianOpportunities);
      await applyTo(tester);
      expect(find.text('Precio confirmado: 150.000 COP'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar detalle'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('open-my-applications'));
      await tester.tap(key('open-my-applications'));
      await tester.pumpAndSettle();
      expect(find.text('150.000 COP'), findsOneWidget);
      await tester.tap(find.byTooltip('Actualizar postulaciones'));
      await tester.pumpAndSettle();
      expect(find.text('150.000 COP'), findsOneWidget);
      expect(applications.applied.length, 1);
    });

    testWidgets('si no puede postularse, explica el motivo', (tester) async {
      applications.failure = const ApplicationFailure(
        'No puedes postularte.',
        reasons: [IneligibilityReason.zone],
      );
      await pump(tester, _technician, AppRoutes.technicianOpportunities);

      await applyTo(tester);

      expect(find.text(IneligibilityReason.zone.message), findsOneWidget);
      expect(applications.applied, isEmpty);
    });

    testWidgets('si la sesión venció al consultar, lleva al login',
        (tester) async {
      opportunities.failure =
          const OpportunityFailure('Sesión vencida', isSessionExpired: true);

      final store =
          await pump(tester, _technician, AppRoutes.technicianOpportunities);

      expect(store.isAuthenticated, isFalse);
      expect(key('login-submit'), findsOneWidget);
    });
  });
}
