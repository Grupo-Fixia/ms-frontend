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

/// Acceso al chat prototipo (GC-431): solo con sesión. Ya no se ofrece desde
/// el inicio; el chat vive en cada servicio contratado. Complementa `navigation_by_role_test.dart`.

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

  // El chat ahora se abre desde cada servicio contratado
  // (service_chat_test.dart); el inicio ya no muestra el de demostración.
  testWidgets('el inicio del cliente ya no ofrece el chat de demostración',
      (tester) async {
    await _pump(tester, profile: _client);
    await _open(tester, AppRoutes.clientDashboard);

    expect(find.byTooltip('Abrir chat'), findsNothing);
    expect(find.text('Chat de demostración'), findsNothing);
  });

  testWidgets('el inicio del técnico ya no ofrece el chat de demostración',
      (tester) async {
    await _pump(tester, profile: _technician);
    await _open(tester, AppRoutes.technicianDashboard);

    expect(find.byKey(const ValueKey('technician-open-chat-prototype')),
        findsNothing);
  });

  testWidgets('con sesión, la ruta /demo/chat abre la simulación',
      (tester) async {
    await _pump(tester, profile: _client);

    await _open(tester, AppRoutes.chatPrototype);

    expect(find.byType(ChatPrototypePage), findsOneWidget);
  });
}
