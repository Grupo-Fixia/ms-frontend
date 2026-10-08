import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile_exceptions.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';
import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

Future<FakeAuthRepository> _pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? authRepository,
  FakeSessionStorage? storage,
  SessionStore? sessionStore,
  bool openLogin = true,
  FakeAccountRegistrationRepository? technicianRepository,
  FakeTechnicianProfileRepository? profileRepository,
}) async {
  tester.view.physicalSize = const Size(1024, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = authRepository ?? FakeAuthRepository();
  await tester.pumpWidget(
    FixiaApp(
      clientRegistrationRepository: FakeAccountRegistrationRepository(),
      technicianRegistrationRepository: technicianRepository ??
          FakeAccountRegistrationRepository(),
      technicianProfileRepository: profileRepository ??
          FakeTechnicianProfileRepository(profile: emptyProfile),
      authRepository: repository,
      sessionStorage: storage ?? FakeSessionStorage(),
      sessionStore: sessionStore,
    ),
  );
  await tester.pumpAndSettle();
  // Sin sesión la app abre en la página de inicio; la mayoría de pruebas
  // parten del login, así que se entra desde ahí.
  final homeLogin = find.byKey(const ValueKey('home-login'));
  if (openLogin && homeLogin.evaluate().isNotEmpty) {
    await tester.tap(homeLogin);
    await tester.pumpAndSettle();
  }
  return repository;
}

void main() {
  testWidgets('sin sesión la app arranca en la página de inicio',
      (tester) async {
    await _pumpApp(tester, openLogin: false);

    expect(find.byKey(const ValueKey('home-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit')), findsNothing);
  });

  testWidgets('de la página de inicio se llega al login y al registro',
      (tester) async {
    await _pumpApp(tester, openLogin: false);

    await tester.tap(find.byKey(const ValueKey('home-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-hero-cta')));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
  });

  testWidgets('"Soy técnico" abre el registro de técnico y se puede cambiar '
      'a cliente', (tester) async {
    await _pumpApp(tester, openLogin: false);

    final technicianButton =
        find.byKey(const ValueKey('home-register-technician'));
    await tester.ensureVisible(technicianButton);
    await tester.pumpAndSettle();
    await tester.tap(technicianButton);
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta de técnico'), findsOneWidget);

    final switchRole = find.byKey(const ValueKey('registration-switch-role'));
    await tester.ensureVisible(switchRole);
    await tester.tap(switchRole);
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Crea tu cuenta de técnico'), findsNothing);
  });

  testWidgets('al crear la cuenta de técnico inicia sesión y pasa al paso 2',
      (tester) async {
    final authRepository = FakeAuthRepository(profile: _technicianProfile);
    await _pumpApp(tester, openLogin: false, authRepository: authRepository);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.technicianRegistration);
    await tester.pumpAndSettle();
    await _fillTechnicianForm(tester);
    final submit = find.byKey(const ValueKey('registration-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(authRepository.loginCalls, 1);
    expect(authRepository.lastEmail, 'luis@fixia.com');
    expect(authRepository.lastPassword, 'Segura123');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('technician-profile-title')))
          .data,
      'Completa tu perfil profesional',
    );
  });

  testWidgets('si la sesión del técnico vence, vuelve al login',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, _technicianProfile);
    await _pumpApp(
      tester,
      sessionStore: store,
      profileRepository: FakeTechnicianProfileRepository(
        profile: emptyProfile,
        fetchFailure: const TechnicianProfileFailure(
          'Tu sesión expiró',
          isSessionExpired: true,
        ),
      ),
    );

    expect(store.isAuthenticated, isFalse);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('el registro de técnico usa su propio repositorio',
      (tester) async {
    final technicianRepository = FakeAccountRegistrationRepository();
    await _pumpApp(
      tester,
      openLogin: false,
      technicianRepository: technicianRepository,
    );

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.technicianRegistration);
    await tester.pumpAndSettle();

    Finder field(String name) => find.byKey(ValueKey('registration-$name-field'));
    await tester.enterText(field('firstName'), 'Luis');
    await tester.enterText(field('lastName'), 'Gómez');
    await tester.tap(field('documentType'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cédula de ciudadanía').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('documentNumber'), '80123456');
    await tester.enterText(field('email'), 'luis@fixia.com');
    await tester.enterText(field('phone'), '3109876543');
    await tester.enterText(field('password'), 'Segura123');
    await tester.enterText(field('confirmPassword'), 'Segura123');
    final consent = find.byKey(const ValueKey('registration-consent-checkbox'));
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pump();
    final submit = find.byKey(const ValueKey('registration-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(technicianRepository.calls, 1);
    expect(technicianRepository.saved?.email, 'luis@fixia.com');
    // Tras crear la cuenta inicia sesión sola y sale del registro.
    expect(find.byKey(const ValueKey('registration-success')), findsNothing);
  });

  testWidgets('un técnico con sesión llega a completar su perfil (paso 2)',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, _technicianProfile);
    await _pumpApp(tester, sessionStore: store);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('technician-profile-title')))
          .data,
      'Completa tu perfil profesional',
    );
    expect(find.text('Hola, Ana'), findsNothing);
  });

  testWidgets('el técnico con perfil completo ve su resumen y puede salir',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, _technicianProfile);
    final repository = await _pumpApp(
      tester,
      sessionStore: store,
      profileRepository:
          FakeTechnicianProfileRepository(profile: completeProfile()),
    );

    expect(find.text('Hola, Luis'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('technician-profile-logout')));
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('con sesión iniciada, la página de inicio muestra la sesión',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, fixtureProfile);
    await _pumpApp(tester, sessionStore: store);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-title')), findsNothing);
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('del login se llega al registro y de vuelta', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('flujo completo: login, cuenta en pantalla y cierre de sesión',
      (tester) async {
    final repository = await _pumpApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'ana@fixia.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'Segura123',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('ana@fixia.com'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('session-logout')));
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(find.text('Hola, Ana'), findsNothing);
  });

  testWidgets('con una sesión restaurada la app abre en la pantalla de sesión',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, fixtureProfile);

    await _pumpApp(tester, sessionStore: store);

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit')), findsNothing);
  });

  testWidgets('con sesión iniciada, ir a /login muestra la sesión',
      (tester) async {
    final store = SessionStore()..start(fixtureSession, fixtureProfile);
    await _pumpApp(tester, sessionStore: store);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.login);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-submit')), findsNothing);
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('"mantener sesión": se guarda al entrar y se borra al salir',
      (tester) async {
    final storage = FakeSessionStorage();
    await _pumpApp(tester, storage: storage);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'ana@fixia.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'Segura123',
    );
    await tester.tap(find.byKey(const ValueKey('login-remember-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(storage.refreshToken, fixtureSession.refreshToken);

    await tester.tap(find.byKey(const ValueKey('session-logout')));
    await tester.pumpAndSettle();

    expect(storage.refreshToken, isNull);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('un login rechazado se queda en la pantalla de login',
      (tester) async {
    await _pumpApp(
      tester,
      authRepository: FakeAuthRepository(
        loginFailure: const AuthFailure('Credenciales inválidas'),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'ana@fixia.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'mala',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Credenciales inválidas'), findsOneWidget);
    expect(find.text('Hola, Ana'), findsNothing);
  });

  testWidgets('sin sesión no se puede entrar a la pantalla de sesión',
      (tester) async {
    await _pumpApp(tester);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.session);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('session-card')), findsNothing);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });
}

const _technicianProfile = UserProfile(
  id: 'tec-user-1',
  email: 'luis@fixia.com',
  firstName: 'Luis',
  lastName: 'Gómez',
  role: UserRole.professional,
);

Future<void> _fillTechnicianForm(WidgetTester tester) async {
  Finder field(String name) => find.byKey(ValueKey('registration-$name-field'));
  await tester.enterText(field('firstName'), 'Luis');
  await tester.enterText(field('lastName'), 'Gómez');
  await tester.tap(field('documentType'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cédula de ciudadanía').last);
  await tester.pumpAndSettle();
  await tester.enterText(field('documentNumber'), '80123456');
  await tester.enterText(field('email'), 'luis@fixia.com');
  await tester.enterText(field('phone'), '3109876543');
  await tester.enterText(field('password'), 'Segura123');
  await tester.enterText(field('confirmPassword'), 'Segura123');
  final consent = find.byKey(const ValueKey('registration-consent-checkbox'));
  await tester.ensureVisible(consent);
  await tester.tap(consent);
  await tester.pump();
}
