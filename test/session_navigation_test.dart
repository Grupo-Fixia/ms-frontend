import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/auth/registration/domain/document_type.dart';
import 'package:ms_frontend/features/client/profile/presentation/client_profile_page.dart';
import 'package:ms_frontend/features/technician/opportunities/presentation/technician_opportunities_page.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';
import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

/// Sesión, rol y navegación del inicio (GC-315): rutas reales de los paneles,
/// registro de cliente con ingreso automático y regreso a la ruta pedida tras
/// iniciar sesión. Complementa `navigation_by_role_test.dart` (GC-314).

const _technician = UserProfile(
  id: 'usr-tec',
  email: 'tecnico@fixia.com',
  firstName: 'Tomás',
  lastName: 'Rojas',
  role: UserRole.professional,
);

/// Cuenta con un rol que el frontend no conoce (`UserRole.fromApi` da `null`).
const _unknownRole = UserProfile(
  id: 'usr-x',
  email: 'x@fixia.com',
  firstName: 'Xavi',
  lastName: 'Rol',
  role: null,
);

Future<SessionStore> _pump(
  WidgetTester tester, {
  UserProfile? profile,
  FakeAuthRepository? auth,
  FakeAccountRegistrationRepository? registration,
}) async {
  tester.view.physicalSize = const Size(1024, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = SessionStore();
  if (profile != null) store.start(fixtureSession, profile);
  await tester.pumpWidget(
    FixiaApp(
      clientRegistrationRepository:
          registration ?? FakeAccountRegistrationRepository(),
      technicianRegistrationRepository: FakeAccountRegistrationRepository(),
      technicianProfileRepository:
          FakeTechnicianProfileRepository(profile: emptyProfile),
      authRepository: auth ?? FakeAuthRepository(),
      sessionStorage: FakeSessionStorage(),
      sessionStore: store,
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> _open(WidgetTester tester, String route) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

/// Escribe las credenciales en el login y las envía.
Future<void> _login(WidgetTester tester) async {
  await tester.enterText(_key('login-email-field'), 'ana@fixia.com');
  await tester.enterText(_key('login-password-field'), 'Segura123');
  await tester.ensureVisible(_key('login-submit'));
  await tester.tap(_key('login-submit'));
  await tester.pumpAndSettle();
}

Future<void> _fillClientRegistration(WidgetTester tester) async {
  Finder field(String name) => _key('registration-$name-field');
  await tester.enterText(field('firstName'), 'Ana');
  await tester.enterText(field('lastName'), 'Pérez');
  await tester.tap(field('documentType'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(DocumentType.cc.label).last);
  await tester.pumpAndSettle();
  await tester.enterText(field('documentNumber'), '1020304050');
  await tester.enterText(field('email'), 'ana@fixia.com');
  await tester.enterText(field('phone'), '3001234567');
  await tester.enterText(field('password'), 'Segura123');
  await tester.enterText(field('confirmPassword'), 'Segura123');
  await tester.ensureVisible(_key('registration-consent-checkbox'));
  await tester.tap(_key('registration-consent-checkbox'));
  await tester.pump();
  await tester.ensureVisible(_key('registration-submit'));
  await tester.tap(_key('registration-submit'));
  await tester.pumpAndSettle();
}

void main() {
  group('rutas reales de los paneles', () {
    test('ya no anuncian «demo» en la URL', () {
      expect(AppRoutes.clientDashboard, '/cliente/inicio');
      expect(AppRoutes.technicianDashboard, '/tecnico/inicio');
      expect(AppRoutes.clientDashboard, isNot(contains('demo')));
      expect(AppRoutes.technicianDashboard, isNot(contains('demo')));
    });

    testWidgets('el cliente abre su panel', (tester) async {
      await _pump(tester, profile: fixtureProfile);

      await _open(tester, AppRoutes.clientDashboard);

      expect(_key('client-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('el técnico abre su panel', (tester) async {
      await _pump(tester, profile: _technician);

      await _open(tester, AppRoutes.technicianDashboard);

      expect(_key('technician-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('el cliente no entra al panel del técnico y vuelve al suyo',
        (tester) async {
      await _pump(tester, profile: fixtureProfile);

      await _open(tester, AppRoutes.technicianDashboard);

      expect(_key('technician-dashboard-greeting'), findsNothing);
      expect(_key('client-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('el técnico no entra al panel del cliente y vuelve al suyo',
        (tester) async {
      await _pump(tester, profile: _technician);

      await _open(tester, AppRoutes.clientDashboard);

      expect(_key('client-dashboard-greeting'), findsNothing);
      expect(_key('technician-dashboard-greeting'), findsOneWidget);
    });
  });

  group('rutas anteriores «demo»', () {
    testWidgets('llevan al panel del rol con sesión', (tester) async {
      await _pump(tester, profile: fixtureProfile);
      await _open(tester, AppRoutes.legacyClientDashboard);
      expect(_key('client-dashboard-greeting'), findsOneWidget);

      await _open(tester, AppRoutes.legacyTechnicianDashboard);
      expect(_key('client-dashboard-greeting'), findsOneWidget,
          reason: 'un cliente que abre la ruta vieja del técnico queda en su panel');
    });

    testWidgets('para el técnico llevan a su panel', (tester) async {
      await _pump(tester, profile: _technician);

      await _open(tester, AppRoutes.legacyTechnicianDashboard);
      expect(_key('technician-dashboard-greeting'), findsOneWidget);

      await _open(tester, AppRoutes.legacyClientDashboard);
      expect(_key('technician-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('sin sesión llevan al login', (tester) async {
      await _pump(tester);

      await _open(tester, AppRoutes.legacyClientDashboard);

      expect(_key('login-submit'), findsOneWidget);
      expect(_key('client-dashboard-greeting'), findsNothing);
    });
  });

  group('rol que el frontend no conoce', () {
    testWidgets('el inicio muestra la cuenta y no un panel de rol',
        (tester) async {
      await _pump(tester, profile: _unknownRole);

      expect(_key('client-dashboard-greeting'), findsNothing);
      expect(_key('technician-dashboard-greeting'), findsNothing);
      expect(_key('session-logout'), findsOneWidget);
    });

    testWidgets('no entra a ninguna ruta de rol', (tester) async {
      await _pump(tester, profile: _unknownRole);

      for (final route in [
        AppRoutes.clientDashboard,
        AppRoutes.technicianDashboard,
        AppRoutes.clientProfile,
        AppRoutes.technicianOpportunities,
        AppRoutes.technicianProfile,
      ]) {
        await _open(tester, route);

        expect(_key('client-dashboard-greeting'), findsNothing, reason: route);
        expect(_key('technician-dashboard-greeting'), findsNothing,
            reason: route);
        expect(_key('session-logout'), findsOneWidget, reason: route);
      }
    });
  });

  group('registro de cliente', () {
    testWidgets('inicia sesión solo y deja al cliente en su panel',
        (tester) async {
      final registration = FakeAccountRegistrationRepository();
      final auth = FakeAuthRepository();
      await _pump(tester, registration: registration, auth: auth);
      await _open(tester, AppRoutes.clientRegistration);

      await _fillClientRegistration(tester);

      expect(registration.calls, 1);
      expect(auth.loginCalls, 1, reason: 'ingreso automático');
      expect(auth.lastEmail, 'ana@fixia.com');
      expect(_key('client-dashboard-greeting'), findsOneWidget);
      expect(_key('registration-success'), findsNothing);
    });

    testWidgets('si el ingreso automático falla queda la confirmación',
        (tester) async {
      final auth = FakeAuthRepository(
        loginFailure: const AuthFailure('No se pudo iniciar sesión'),
      );
      await _pump(tester, auth: auth);
      await _open(tester, AppRoutes.clientRegistration);

      await _fillClientRegistration(tester);

      expect(_key('registration-success'), findsOneWidget);
      expect(_key('client-dashboard-greeting'), findsNothing);
    });
  });

  group('volver a la ruta pedida tras iniciar sesión', () {
    testWidgets('el técnico llega a la ruta que había pedido', (tester) async {
      await _pump(tester, auth: FakeAuthRepository(profile: _technician));

      await _open(tester, AppRoutes.technicianOpportunities);
      expect(_key('login-submit'), findsOneWidget);
      await _login(tester);

      expect(find.byType(TechnicianOpportunitiesPage), findsOneWidget);
      expect(_key('login-submit'), findsNothing);
    });

    testWidgets('desde ahí «atrás» lleva a su panel', (tester) async {
      await _pump(tester, auth: FakeAuthRepository(profile: _technician));
      await _open(tester, AppRoutes.technicianOpportunities);
      await _login(tester);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.byType(TechnicianOpportunitiesPage), findsNothing);
      expect(_key('technician-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('un cliente que pidió una ruta del técnico queda en su panel',
        (tester) async {
      await _pump(tester, auth: FakeAuthRepository());

      await _open(tester, AppRoutes.technicianOpportunities);
      await _login(tester);

      expect(find.byType(TechnicianOpportunitiesPage), findsNothing);
      expect(_key('client-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('el cliente llega a su perfil si lo había pedido',
        (tester) async {
      await _pump(tester, auth: FakeAuthRepository());

      await _open(tester, AppRoutes.clientProfile);
      await _login(tester);

      expect(find.byType(ClientProfilePage), findsOneWidget);
      expect(_key('client-dashboard-greeting'), findsNothing);
    });

    testWidgets('un ingreso normal, sin ruta pedida, va al inicio del rol',
        (tester) async {
      await _pump(tester, auth: FakeAuthRepository(profile: _technician));

      await _open(tester, AppRoutes.login);
      await _login(tester);

      expect(_key('technician-dashboard-greeting'), findsOneWidget);
      expect(find.byType(TechnicianOpportunitiesPage), findsNothing);
    });

    testWidgets('el destino se usa una sola vez', (tester) async {
      final store = await _pump(
        tester,
        auth: FakeAuthRepository(profile: _technician),
      );
      await _open(tester, AppRoutes.technicianOpportunities);
      await _login(tester);
      expect(find.byType(TechnicianOpportunitiesPage), findsOneWidget);

      store.clear();
      await tester.pumpAndSettle();
      expect(_key('login-submit'), findsOneWidget);
      await _login(tester);

      expect(find.byType(TechnicianOpportunitiesPage), findsNothing,
          reason: 'la segunda sesión no hereda el destino de la primera');
      expect(_key('technician-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('al terminar una sesión no se recuerda la ruta que se veía',
        (tester) async {
      final store = await _pump(
        tester,
        profile: _technician,
        auth: FakeAuthRepository(profile: _technician),
      );
      await _open(tester, AppRoutes.technicianOpportunities);
      expect(find.byType(TechnicianOpportunitiesPage), findsOneWidget);

      store.clear();
      await tester.pumpAndSettle();
      expect(_key('login-submit'), findsOneWidget);
      await _login(tester);

      // Entra otro técnico (también podría abrir esa ruta): no hereda el
      // destino de la sesión anterior y queda en su panel.
      expect(find.byType(TechnicianOpportunitiesPage), findsNothing);
      expect(_key('technician-dashboard-greeting'), findsOneWidget);
    });

    testWidgets('con las rutas «demo» también termina en el panel del rol',
        (tester) async {
      await _pump(tester, auth: FakeAuthRepository(profile: _technician));

      await _open(tester, AppRoutes.legacyTechnicianDashboard);
      await _login(tester);

      expect(_key('technician-dashboard-greeting'), findsOneWidget);
    });
  });
}
