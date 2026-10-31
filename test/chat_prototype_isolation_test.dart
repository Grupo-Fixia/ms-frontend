import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';
import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

/// Aislamiento del chat prototipo (GC-432): usarlo no toca la sesión ni
/// ningún repositorio de la aplicación.

const _technician = UserProfile(
  id: 'usr-tec',
  email: 'tecnico@fixia.com',
  firstName: 'Tomás',
  lastName: 'Rojas',
  role: UserRole.professional,
);

void main() {
  testWidgets('escribir, reiniciar y salir del chat no genera efectos',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = SessionStore()..start(fixtureSession, _technician);
    final auth = FakeAuthRepository();
    final storage = FakeSessionStorage();
    final technicianRepo =
        FakeTechnicianProfileRepository(profile: emptyProfile);
    await tester.pumpWidget(
      FixiaApp(
        clientRegistrationRepository: FakeAccountRegistrationRepository(),
        technicianRegistrationRepository: FakeAccountRegistrationRepository(),
        technicianProfileRepository: technicianRepo,
        authRepository: auth,
        sessionStorage: storage,
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.technicianDashboard);
    await tester.pumpAndSettle();

    final session = store.session;
    final profile = store.profile;
    final fetches = technicianRepo.fetchCalls;
    final auths = [
      auth.loginCalls,
      auth.profileCalls,
      auth.logoutCalls,
      auth.refreshCalls,
    ];
    final storageClears = storage.clearCalls;

    final open = find.byKey(const ValueKey('technician-open-chat-prototype'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();

    for (final text in ['uno', 'dos', 'tres']) {
      await tester.enterText(
          find.byKey(const ValueKey('chat-prototype-input')), text);
      await tester.tap(find.byKey(const ValueKey('chat-prototype-send')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('chat-prototype-reset')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(technicianRepo.fetchCalls, fetches,
        reason: 'el chat no consulta el perfil');
    expect(technicianRepo.updateCalls, 0, reason: 'el chat no actualiza datos');
    expect([
      auth.loginCalls,
      auth.profileCalls,
      auth.logoutCalls,
      auth.refreshCalls,
    ], auths);
    expect(storage.clearCalls, storageClears);
    expect(store.session, same(session));
    expect(store.profile, same(profile));
    expect(store.isAuthenticated, isTrue);
  });
}
