import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/chat_prototype/presentation/chat_prototype_page.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';
import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

/// Acceso al chat prototipo (GC-431): solo con sesión y desde el inicio de
/// cliente y técnico. Complementa `navigation_by_role_test.dart`.

const _client = UserProfile(
  id: 'usr-cli',
  email: 'cliente@fixia.com',
  firstName: 'Ana',
  lastName: 'Cliente',
  role: UserRole.client,
);

const _technician = UserProfile(
  id: 'usr-tec',
  email: 'tecnico@fixia.com',
  firstName: 'Tomás',
  lastName: 'Rojas',
  role: UserRole.professional,
);

Future<void> _pump(WidgetTester tester, {UserProfile? profile}) async {
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
}

Future<void> _open(WidgetTester tester, String route) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin sesión, /demo/chat lleva al login', (tester) async {
    await _pump(tester);

    await _open(tester, AppRoutes.chatPrototype);

    expect(find.byType(ChatPrototypePage), findsNothing);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('el cliente abre el chat desde «Abrir chat»', (tester) async {
    await _pump(tester, profile: _client);
    await _open(tester, AppRoutes.clientDashboard);

    final button = find.byTooltip('Abrir chat');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(ChatPrototypePage), findsOneWidget);
    expect(find.textContaining('SIMULACIÓN'), findsOneWidget);
  });

  testWidgets('el técnico abre el chat desde su inicio', (tester) async {
    await _pump(tester, profile: _technician);
    await _open(tester, AppRoutes.technicianDashboard);

    final button = find.byKey(const ValueKey('technician-open-chat-prototype'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(ChatPrototypePage), findsOneWidget);
    expect(find.textContaining('SIMULACIÓN'), findsOneWidget);
  });

  testWidgets('con sesión, la ruta /demo/chat abre la simulación',
      (tester) async {
    await _pump(tester, profile: _client);

    await _open(tester, AppRoutes.chatPrototype);

    expect(find.byType(ChatPrototypePage), findsOneWidget);
  });
}
