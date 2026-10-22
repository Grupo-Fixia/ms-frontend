import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';
import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

/// Navegación protegida por rol (GC-314): cada ruta aplica `RouteGuard`.

const _technician = UserProfile(
  id: 'usr-tec',
  email: 'tecnico@fixia.com',
  firstName: 'Tomás',
  lastName: 'Rojas',
  role: UserRole.professional,
);

const _admin = UserProfile(
  id: 'usr-admin',
  email: 'admin@fixia.com',
  firstName: 'Ada',
  lastName: 'Admin',
  role: UserRole.admin,
);

Future<SessionStore> _pump(WidgetTester tester, {UserProfile? profile}) async {
  tester.view.physicalSize = const Size(1024, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = SessionStore();
  if (profile != null) store.start(fixtureSession, profile);
  await tester.pumpWidget(
    FixiaApp(
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
  return store;
}

Future<void> _open(WidgetTester tester, String route) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  group('con sesión, login y registro llevan al inicio del rol', () {
    for (final route in [
      AppRoutes.login,
      AppRoutes.clientRegistration,
      AppRoutes.technicianRegistration,
    ]) {
      testWidgets('cliente en $route', (tester) async {
        await _pump(tester, profile: fixtureProfile);

        await _open(tester, route);

        expect(_key('client-dashboard-greeting'), findsOneWidget);
        expect(_key('login-submit'), findsNothing);
        expect(_key('registration-submit'), findsNothing);
      });
    }
  });

  testWidgets('un cliente que abre el perfil del técnico vuelve a su inicio',
      (tester) async {
    await _pump(tester, profile: fixtureProfile);

    await _open(tester, AppRoutes.technicianProfile);

    expect(_key('client-dashboard-greeting'), findsOneWidget);
    expect(_key('login-submit'), findsNothing);
  });

  testWidgets('sin sesión, el perfil del técnico lleva al login',
      (tester) async {
    await _pump(tester);

    await _open(tester, AppRoutes.technicianProfile);

    expect(_key('login-submit'), findsOneWidget);
  });

  testWidgets('el técnico sí abre su perfil', (tester) async {
    await _pump(tester, profile: _technician);

    await _open(tester, AppRoutes.technicianProfile);

    expect(_key('technician-dashboard-greeting'), findsNothing);
    expect(_key('login-submit'), findsNothing);
  });

  testWidgets('un administrador no entra a las rutas de cliente ni técnico',
      (tester) async {
    await _pump(tester, profile: _admin);

    for (final route in [
      AppRoutes.clientDashboard,
      AppRoutes.technicianDashboard,
      AppRoutes.technicianProfile,
    ]) {
      await _open(tester, route);

      expect(_key('client-dashboard-greeting'), findsNothing);
      expect(_key('technician-dashboard-greeting'), findsNothing);
      expect(_key('session-logout'), findsOneWidget, reason: route);
    }
  });

  testWidgets('una URL que no existe lleva al inicio', (tester) async {
    await _pump(tester);

    await _open(tester, '/no-existe');

    expect(_key('home-title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si la sesión se cierra en una ruta protegida, va al login',
      (tester) async {
    final store = await _pump(tester, profile: fixtureProfile);
    await _open(tester, AppRoutes.clientDashboard);
    expect(_key('client-dashboard-greeting'), findsOneWidget);

    store.clear();
    await tester.pumpAndSettle();

    expect(_key('login-submit'), findsOneWidget);
    expect(_key('client-dashboard-greeting'), findsNothing);
  });

  testWidgets('cerrar sesión desde el inicio del cliente navega una sola vez',
      (tester) async {
    await _pump(tester, profile: fixtureProfile);
    await _open(tester, AppRoutes.clientDashboard);

    await tester.ensureVisible(_key('client-dashboard-logout'));
    await tester.tap(_key('client-dashboard-logout'));
    await tester.pumpAndSettle();

    expect(_key('login-submit'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse, reason: 'solo queda el login');
    expect(tester.takeException(), isNull);
  });
}
