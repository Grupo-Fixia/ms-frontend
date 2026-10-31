import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/company/technicians/domain/company_exceptions.dart';
import 'package:ms_frontend/features/company/technicians/presentation/widgets/associated_technician_tile.dart';
import 'package:ms_frontend/main.dart';

import '../auth/login/fake_auth_repository.dart';
import '../auth/registration/fake_repository.dart';
import '../technician/profile/fake_repository.dart';
import '../technician/profile/fixtures.dart';
import 'technicians/fake_company_repository.dart';

const _companyProfile = UserProfile(
  id: 'c0a00000-0000-4000-8000-000000000001',
  email: 'empresa1@fixia-qa.test',
  firstName: 'Laura',
  lastName: 'Gómez',
  role: UserRole.company,
);

Future<void> _pumpApp(
  WidgetTester tester, {
  SessionStore? sessionStore,
  FakeAuthRepository? authRepository,
  FakeCompanyRepository? companyRepository,
  bool withCompanyRepository = true,
}) async {
  tester.view.physicalSize = const Size(1024, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    FixiaApp(
      clientRegistrationRepository: FakeAccountRegistrationRepository(),
      technicianRegistrationRepository: FakeAccountRegistrationRepository(),
      technicianProfileRepository:
          FakeTechnicianProfileRepository(profile: emptyProfile),
      authRepository: authRepository ?? FakeAuthRepository(),
      sessionStorage: FakeSessionStorage(),
      sessionStore: sessionStore,
      companyRepository: withCompanyRepository
          ? companyRepository ?? FakeCompanyRepository()
          : null,
    ),
  );
  await tester.pumpAndSettle();
}

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

void main() {
  testWidgets('una empresa que inicia sesión llega a su inicio',
      (tester) async {
    await _pumpApp(
      tester,
      authRepository: FakeAuthRepository(profile: _companyProfile),
    );
    await tester.tap(find.byKey(const ValueKey('home-login')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('login-email-field')),
        'empresa1@fixia-qa.test');
    await tester.enterText(
        find.byKey(const ValueKey('login-password-field')), 'Clave#2026');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Laura'), findsOneWidget);
    expect(find.text('Servicios Integrales Andina'), findsOneWidget);
  });

  testWidgets('desde el inicio de la empresa se ven sus técnicos reales',
      (tester) async {
    final repository = FakeCompanyRepository();
    await _pumpApp(
      tester,
      sessionStore: SessionStore()..start(fixtureSession, _companyProfile),
      companyRepository: repository,
    );
    _navigator(tester).pushNamed(AppRoutes.companyDashboard);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('company-open-technicians')));
    await tester.pumpAndSettle();

    expect(find.text('Mis técnicos'), findsOneWidget);
    expect(find.byType(AssociatedTechnicianTile), findsNWidgets(2));
    expect(repository.techniciansCalls, 1);

    // Volver y entrar de nuevo vuelve a consultar lo persistido.
    await tester.tap(find.byTooltip('Volver').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('company-open-technicians')));
    await tester.pumpAndSettle();
    expect(repository.techniciansCalls, 2);
  });

  testWidgets('sin sesión, las rutas de empresa llevan al login',
      (tester) async {
    for (final route in [
      AppRoutes.companyDashboard,
      AppRoutes.companyTechnicians,
    ]) {
      await _pumpApp(tester);
      _navigator(tester).pushNamed(route);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    }
  });

  testWidgets('un cliente no entra a las rutas de empresa', (tester) async {
    await _pumpApp(
      tester,
      sessionStore: SessionStore()..start(fixtureSession, fixtureProfile),
    );
    _navigator(tester).pushNamed(AppRoutes.companyTechnicians);
    await tester.pumpAndSettle();

    expect(find.text('Mis técnicos'), findsNothing);
    expect(find.byKey(const ValueKey('client-dashboard-greeting')),
        findsOneWidget);
  });

  testWidgets('una empresa no entra a las rutas del cliente', (tester) async {
    await _pumpApp(
      tester,
      sessionStore: SessionStore()..start(fixtureSession, _companyProfile),
    );
    _navigator(tester).pushNamed(AppRoutes.clientDashboard);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('client-dashboard-greeting')),
        findsNothing);
    expect(find.text('Hola, Laura'), findsOneWidget);
  });

  testWidgets('si la sesión vence al cargar la empresa, vuelve al login',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, _companyProfile);
    await _pumpApp(
      tester,
      sessionStore: store,
      companyRepository: FakeCompanyRepository(
        failure: const CompanyFailure('Tu sesión expiró.',
            isSessionExpired: true),
      ),
    );
    _navigator(tester).pushNamed(AppRoutes.companyDashboard);
    await tester.pumpAndSettle();

    expect(store.isAuthenticated, isFalse);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('si la sesión vence en «Mis técnicos», vuelve al login',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, _companyProfile);
    final repository = FakeCompanyRepository();
    await _pumpApp(tester, sessionStore: store, companyRepository: repository);
    _navigator(tester).pushNamed(AppRoutes.companyDashboard);
    await tester.pumpAndSettle();

    repository.failure =
        const CompanyFailure('Tu sesión expiró.', isSessionExpired: true);
    await tester.tap(find.byKey(const ValueKey('company-open-technicians')));
    await tester.pumpAndSettle();

    expect(store.isAuthenticated, isFalse);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('sin conexión configurada, las pantallas de empresa lo dicen',
      (tester) async {
    await _pumpApp(
      tester,
      sessionStore: SessionStore()..start(fixtureSession, _companyProfile),
      withCompanyRepository: false,
    );
    _navigator(tester).pushNamed(AppRoutes.companyDashboard);
    await tester.pumpAndSettle();
    expect(find.textContaining('requiere conexión'), findsOneWidget);

    _navigator(tester).pushNamed(AppRoutes.companyTechnicians);
    await tester.pumpAndSettle();
    expect(find.textContaining('requiere conexión'), findsOneWidget);
  });
}
