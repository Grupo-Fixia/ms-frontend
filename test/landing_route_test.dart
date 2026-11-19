import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/home/presentation/home_page.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/login/fake_auth_repository.dart';
import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

/// Landing pública en `/landingpage` dentro de la app (GC-538): la raíz `/`
/// lleva a la cuenta con sesión y a la landing sin sesión.

Future<NavigatorState> _pump(WidgetTester tester,
    {UserProfile? profile}) async {
  tester.view.physicalSize = const Size(1024, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = SessionStore();
  if (profile != null) store.start(fixtureSession, profile);
  await tester.pumpWidget(FixiaApp(
    clientRegistrationRepository: FakeAccountRegistrationRepository(),
    technicianRegistrationRepository: FakeAccountRegistrationRepository(),
    technicianProfileRepository:
        FakeTechnicianProfileRepository(profile: emptyProfile),
    authRepository: FakeAuthRepository(),
    sessionStorage: FakeSessionStorage(),
    sessionStore: store,
  ));
  await tester.pumpAndSettle();
  return tester.state<NavigatorState>(find.byType(Navigator));
}

Finder _key(String key) => find.byKey(ValueKey(key));

String? _currentRoute(WidgetTester tester) {
  String? name;
  tester.state<NavigatorState>(find.byType(Navigator)).popUntil((route) {
    name = route.settings.name;
    return true;
  });
  return name;
}

void main() {
  test('la landing vive en /landingpage', () {
    expect(AppRoutes.landing, '/landingpage');
    expect(AppRoutes.home, '/');
  });

  testWidgets('sin sesión, la raíz lleva a /landingpage', (tester) async {
    await _pump(tester);
    expect(_key('home-title'), findsOneWidget);
    expect(_currentRoute(tester), AppRoutes.landing);
  });

  testWidgets('con sesión, la raíz lleva al inicio de la cuenta',
      (tester) async {
    await _pump(tester, profile: fixtureProfile);
    expect(_key('client-dashboard-greeting'), findsOneWidget);
    expect(_key('home-title'), findsNothing);
    expect(_currentRoute(tester), AppRoutes.clientDashboard);
  });

  testWidgets('la landing se puede abrir con sesión', (tester) async {
    final nav = await _pump(tester, profile: fixtureProfile);
    nav.pushNamed(AppRoutes.landing);
    await tester.pumpAndSettle();
    expect(_key('home-title'), findsOneWidget);
  });

  testWidgets('una ruta desconocida sin sesión cae en la landing',
      (tester) async {
    final nav = await _pump(tester);
    nav.pushNamed('/landingpage/no-existe');
    await tester.pumpAndSettle();
    expect(_key('home-title'), findsOneWidget);
    expect(_currentRoute(tester), AppRoutes.landing);
  });

  testWidgets('desde la landing se llega al login y a los registros',
      (tester) async {
    await _pump(tester);
    await tester.tap(_key('home-login'));
    await tester.pumpAndSettle();
    expect(_key('login-submit'), findsOneWidget);
  });

  testWidgets('fuera de la web la landing no ofrece el APK', (tester) async {
    await _pump(tester);
    expect(_key('home-download-apk'), findsNothing);
  });

  group('sección del APK', () {
    Future<void> pumpHome(WidgetTester tester, Size size,
        {VoidCallback? onDownloadApk}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: HomePage(
          onRegisterClient: () {},
          onLogin: () {},
          onDownloadApk: onDownloadApk,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('sin APK publicado no aparece', (tester) async {
      await pumpHome(tester, const Size(1280, 900));
      expect(_key('home-download-apk'), findsNothing);
    });

    for (final (label, size) in const [
      ('escritorio', Size(1280, 900)),
      ('celular', Size(390, 844)),
    ]) {
      testWidgets('$label: con APK aparece y descarga', (tester) async {
        var downloads = 0;
        await pumpHome(tester, size, onDownloadApk: () => downloads++);
        await tester.ensureVisible(_key('home-download-apk'));
        await tester.tap(_key('home-download-apk'));
        expect(downloads, 1);
        expect(find.text('Fixia en tu celular'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
