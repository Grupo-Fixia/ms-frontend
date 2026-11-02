import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/backend_integrations.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/company/technicians/infrastructure/http_company_repository.dart';
import 'package:ms_frontend/main.dart';
import '../auth/login/fake_auth_repository.dart';
import '../auth/registration/fake_repository.dart';
import '../technician/profile/fake_repository.dart';
import '../technician/profile/fixtures.dart';

const company = UserProfile(
    id: 'company-1',
    email: 'empresa@example.test',
    firstName: 'Laura',
    lastName: 'Gómez',
    role: UserRole.company);
http.Response json(int status, Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
Map<String, Object?> opportunity() => {
      'id': 'request-1',
      'category': 'PLUMBING',
      'description': 'Reparar fuga',
      'city': 'Bogotá',
      'zone': 'Chapinero',
      'expectedAt': '2026-11-10T15:00:00Z',
      'eligibleTechnicianIds': ['user-1']
    };
Map<String, Object?> application() => {
      'id': 'application-1',
      'status': 'APPLIED',
      'providerType': 'COMPANY',
      'technicianId': 'user-1',
      'proposedAmount': 150000,
      'currency': 'COP',
      'serviceRequest': {
        'id': 'request-1',
        'category': 'PLUMBING',
        'city': 'Bogotá',
        'zone': 'Chapinero'
      }
    };
Future<void> pump(
    WidgetTester tester, SessionStore store, MockClientHandler handler) async {
  tester.view.physicalSize = const Size(1024, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = MockClient(handler);
  final auth = AuthorizedHttp(
      accessToken: () => store.session?.accessToken,
      renewSession: () async => false);
  final base = Uri.parse('http://localhost');
  await tester.pumpWidget(FixiaApp(
    clientRegistrationRepository: FakeAccountRegistrationRepository(),
    technicianRegistrationRepository: FakeAccountRegistrationRepository(),
    technicianProfileRepository:
        FakeTechnicianProfileRepository(profile: emptyProfile),
    authRepository: FakeAuthRepository(profile: company),
    sessionStorage: FakeSessionStorage(),
    sessionStore: store,
    companyRepository: HttpCompanyRepository(
        client: client, baseUrl: base, authorizedHttp: auth),
    backend: BackendIntegrations.http(
        client: client,
        usersBaseUrl: base,
        servicesBaseUrl: base,
        authorizedHttp: auth),
  ));
  await tester.pumpAndSettle();
}

NavigatorState navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));
void main() {
  testWidgets(
      'dashboard y Mis técnicos comparten controlador con postulación y consulta',
      (tester) async {
    var technicianQueries = 0;
    var posts = 0;
    Map<String, dynamic>? body;
    final store = SessionStore()..start(fixtureSession, company);
    await pump(tester, store, (request) async {
      expect(request.headers['Authorization'], 'Bearer access-token');
      if (request.url.path.endsWith('/companies/me')) {
        return json(200, {
          'id': 'company-1',
          'name': 'Empresa real de la API',
          'nit': 'test'
        });
      }
      if (request.url.path.endsWith('/technicians')) {
        technicianQueries++;
        return json(200, {
          'technicians': [
            {
              'userId': 'user-1',
              'displayName': 'Carlos',
              'categories': ['PLUMBING']
            },
            {
              'userId': 'user-2',
              'displayName': 'Luisa',
              'categories': ['PLUMBING']
            }
          ]
        });
      }
      if (request.url.path.endsWith('/opportunities')) {
        return json(200, {
          'items': [opportunity()],
          'nextCursor': null
        });
      }
      if (request.method == 'POST') {
        posts++;
        body = jsonDecode(request.body);
        return json(201, application());
      }
      return json(
          200,
          request.url.path.endsWith('application-1')
              ? application()
              : [application()]);
    });
    navigator(tester).pushNamed(AppRoutes.companyDashboard);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('company-open-technicians')));
    await tester.pumpAndSettle();
    expect(technicianQueries, 1);
    navigator(tester).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('company-open-opportunities')));
    await tester.pumpAndSettle();
    expect(find.text('Oportunidades empresariales'), findsOneWidget);
    expect(technicianQueries, 2);
    await tester
        .tap(find.byKey(const ValueKey('company-opportunity-request-1')));
    await tester.pumpAndSettle();
    expect(technicianQueries, 2);
    await tester.tap(find.byKey(const ValueKey('company-technician-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Luisa'), findsNothing);
    await tester.tap(find.text('Carlos').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('application-price')), '150000');
    await tester
        .ensureVisible(find.byKey(const ValueKey('application-price-submit')));
    await tester.tap(find.byKey(const ValueKey('application-price-submit')));
    await tester.pumpAndSettle();
    expect(body, {
      'serviceRequestId': 'request-1',
      'technicianId': 'user-1',
      'proposedAmount': 150000,
      'currency': 'COP'
    });
    expect(posts, 1);
    expect(find.text('Precio confirmado: 150.000 COP'), findsOneWidget);
  });
  for (final role in [UserRole.client, UserRole.professional]) {
    testWidgets('la ruta de oportunidades no admite $role', (tester) async {
      var queries = 0;
      await pump(tester,
          SessionStore()..start(fixtureSession, company.copyWith(role: role)),
          (_) async {
        queries++;
        return json(500, {});
      });
      navigator(tester).pushNamed(AppRoutes.companyOpportunities);
      await tester.pumpAndSettle();
      expect(find.text('Oportunidades empresariales'), findsNothing);
      expect(queries, 0);
    });
  }
  testWidgets('sin sesión vuelve al login sin consultas empresariales',
      (tester) async {
    var queries = 0;
    await pump(tester, SessionStore(), (_) async {
      queries++;
      return json(500, {});
    });
    navigator(tester).pushNamed(AppRoutes.companyOpportunities);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(queries, 0);
  });
  for (final source in ['technicians', 'opportunities']) {
    testWidgets('expiración en $source cierra la sesión existente',
        (tester) async {
      final store = SessionStore()..start(fixtureSession, company);
      await pump(
          tester,
          store,
          (request) async => request.url.path.endsWith('/$source')
              ? json(401, {})
              : json(
                  200,
                  source == 'technicians'
                      ? {'items': [], 'nextCursor': null}
                      : {'technicians': []}));
      navigator(tester).pushNamed(AppRoutes.companyOpportunities);
      await tester.pumpAndSettle();
      expect(store.isAuthenticated, isFalse);
      expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('cerrar sesión retira oportunidades y datos del selector',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, company);
    await pump(
        tester,
        store,
        (request) async => json(
            200,
            request.url.path.endsWith('technicians')
                ? {'technicians': []}
                : {
                    'items': [opportunity()]
                  }));
    navigator(tester).pushNamed(AppRoutes.companyOpportunities);
    await tester.pumpAndSettle();
    store.clear();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('company-opportunity-request-1')),
        findsNothing);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });
}
