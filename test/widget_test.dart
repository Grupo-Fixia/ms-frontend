import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/client/registration/domain/client_registration.dart';
import 'package:ms_frontend/features/client/registration/domain/client_registration_exceptions.dart';
import 'package:ms_frontend/features/client/registration/domain/document_type.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';

Future<FakeAuthRepository> _pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? authRepository,
  FakeSessionStorage? storage,
  SessionStore? sessionStore,
}) async {
  tester.view.physicalSize = const Size(1024, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = authRepository ?? FakeAuthRepository();
  await tester.pumpWidget(
    FixiaApp(
      clientRegistrationRepository: const PendingClientRegistrationRepository(),
      authRepository: repository,
      sessionStorage: storage ?? FakeSessionStorage(),
      sessionStore: sessionStore,
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('la app arranca en el inicio de sesión', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
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

  test('el repositorio temporal avisa que falta conectar el servicio', () {
    const repository = PendingClientRegistrationRepository();
    final registration = ClientRegistration(
      firstName: 'Ana',
      lastName: 'Pérez',
      documentType: DocumentType.cc,
      documentNumber: '1020304050',
      email: 'ana@fixia.com',
      phone: '3001234567',
      password: 'Segura123',
      policyVersion: 'v1.0',
      consentAccepted: true,
      consentAcceptedAt: DateTime(2026, 10, 6),
    );

    expect(
      repository.register(registration),
      throwsA(isA<ClientRegistrationFailure>()),
    );
  });
}
