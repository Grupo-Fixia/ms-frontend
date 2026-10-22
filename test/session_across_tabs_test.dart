import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/login/application/login_user.dart';
import 'package:ms_frontend/features/auth/login/application/logout_user.dart';
import 'package:ms_frontend/features/auth/login/application/ports/auth_repository.dart';
import 'package:ms_frontend/features/auth/login/application/restore_session.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_session.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/browser_session_storage.dart';
import 'package:ms_frontend/features/auth/login/infrastructure/key_value_store.dart';
import 'package:ms_frontend/main.dart';

import 'features/auth/registration/fake_repository.dart';
import 'features/technician/profile/fake_repository.dart';
import 'features/technician/profile/fixtures.dart';

/// La sesión es una sola en todo el navegador (GC-394): la app sigue lo que
/// pasa en las otras pestañas.

const _ana = UserProfile(
  id: 'usr-ana',
  email: 'ana@fixia.com',
  firstName: 'Ana',
  lastName: 'Pérez',
  role: UserRole.client,
);

const _beto = UserProfile(
  id: 'usr-beto',
  email: 'beto@fixia.com',
  firstName: 'Beto',
  lastName: 'Gómez',
  role: UserRole.professional,
);

/// Backend como ms-users: refresh tokens de un solo uso.
class _Backend implements AuthRepository {
  final Map<String, UserProfile> _refresh = {};
  final Map<String, UserProfile> _access = {};
  var _n = 0;

  AuthSession _issue(UserProfile user) {
    _n++;
    final session = AuthSession(
      accessToken: 'a$_n',
      refreshToken: 'r$_n',
      expiresIn: const Duration(minutes: 15),
    );
    _refresh[session.refreshToken] = user;
    _access[session.accessToken] = user;
    return session;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async =>
      _issue(email == _beto.email ? _beto : _ana);

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final user = _refresh.remove(refreshToken);
    if (user == null) {
      throw const AuthFailure('Sesión inválida', isUnauthorized: true);
    }
    return _issue(user);
  }

  @override
  Future<UserProfile> fetchProfile(String accessToken) async {
    final user = _access[accessToken];
    if (user == null) {
      throw const AuthFailure('Sesión inválida', isUnauthorized: true);
    }
    return user;
  }

  @override
  Future<void> logout(AuthSession session) async {
    _refresh.remove(session.refreshToken);
    _access.remove(session.accessToken);
  }
}

void main() {
  late _Backend backend;
  late InMemoryKeyValueStore local;
  late InMemoryKeyValueStore cookies;
  late StreamController<void> otherTabs;

  setUp(() {
    backend = _Backend();
    local = InMemoryKeyValueStore();
    cookies = InMemoryKeyValueStore();
    otherTabs = StreamController<void>.broadcast();
  });

  tearDown(() => otherTabs.close());

  BrowserSessionStorage newTab() => BrowserSessionStorage(
        tab: InMemoryKeyValueStore(),
        shared: local,
        browserSession: cookies,
      );

  Finder key(String value) => find.byKey(ValueKey(value));

  /// Abre la app en una pestaña nueva, como `main()`: primero restaura.
  /// Con [account] entra al inicio de la cuenta («Iniciar sesión»).
  Future<void> openApp(
    WidgetTester tester,
    BrowserSessionStorage storage, {
    bool account = false,
  }) async {
    tester.view.physicalSize = const Size(1024, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = SessionStore();
    await tester.runAsync(() => RestoreSession(backend, store, storage)());
    await tester.pumpWidget(
      FixiaApp(
        clientRegistrationRepository: FakeAccountRegistrationRepository(),
        technicianRegistrationRepository: FakeAccountRegistrationRepository(),
        technicianProfileRepository:
            FakeTechnicianProfileRepository(profile: emptyProfile),
        authRepository: backend,
        sessionStorage: storage,
        sessionStore: store,
        sessionChangesFromOtherTabs: otherTabs.stream,
      ),
    );
    await tester.pumpAndSettle();
    if (account) {
      await tester.tap(key('home-login'));
      await tester.pumpAndSettle();
    }
  }

  /// Otra pestaña cambia la sesión y el navegador avisa a esta.
  Future<void> otherTabDoes(
    WidgetTester tester,
    Future<void> Function() change,
  ) async {
    await tester.runAsync(change);
    otherTabs.add(null);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(
    BrowserSessionStorage storage, {
    String email = 'ana@fixia.com',
    bool remember = false,
  }) =>
      LoginUser(backend, SessionStore(), storage)(
        email: email,
        password: 'x',
        rememberSession: remember,
      );

  testWidgets(
      'una pestaña nueva muestra la bienvenida y «Iniciar sesión» entra a la '
      'cuenta ya iniciada', (tester) async {
    await tester.runAsync(() => signIn(newTab()));

    await openApp(tester, newTab());
    expect(key('home-title'), findsOneWidget);
    expect(key('client-dashboard-greeting'), findsNothing);

    await tester.tap(key('home-login'));
    await tester.pumpAndSettle();

    expect(key('client-dashboard-greeting'), findsOneWidget);
    expect(key('login-submit'), findsNothing);
  });

  testWidgets('sin sesión, «Iniciar sesión» abre el formulario',
      (tester) async {
    await openApp(tester, newTab());

    await tester.tap(key('home-login'));
    await tester.pumpAndSettle();

    expect(key('login-submit'), findsOneWidget);
  });

  testWidgets('con sesión, "Iniciar sesión" lleva a la cuenta, no al login',
      (tester) async {
    await tester.runAsync(() => signIn(newTab(), remember: true));
    await openApp(tester, newTab());

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.login);
    await tester.pumpAndSettle();

    expect(key('client-dashboard-greeting'), findsOneWidget);
    expect(key('login-submit'), findsNothing);
  });

  testWidgets('si se cierra sesión en otra pestaña, esta va al login',
      (tester) async {
    final other = newTab();
    await tester.runAsync(() => signIn(other));
    await openApp(tester, newTab(), account: true);
    expect(key('client-dashboard-greeting'), findsOneWidget);

    await otherTabDoes(tester, () async {
      final store = SessionStore();
      await RestoreSession(backend, store, other)();
      await LogoutUser(backend, store, other)();
    });

    expect(key('login-submit'), findsOneWidget);
    expect(key('client-dashboard-greeting'), findsNothing);
  });

  testWidgets('si en otra pestaña se entra con otra cuenta, esta la sigue',
      (tester) async {
    final other = newTab();
    await tester.runAsync(() => signIn(other));
    await openApp(tester, newTab(), account: true);

    await otherTabDoes(tester, () async {
      final store = SessionStore();
      await RestoreSession(backend, store, other)();
      await LogoutUser(backend, store, other)();
      await signIn(other, email: 'beto@fixia.com');
    });

    expect(key('client-dashboard-greeting'), findsNothing);
    expect(key('login-submit'), findsNothing);
    expect(key('technician-dashboard-greeting'), findsOneWidget);
  });

  testWidgets('un aviso sin cambios no mueve la pantalla', (tester) async {
    await tester.runAsync(() => signIn(newTab()));
    await openApp(tester, newTab(), account: true);

    await otherTabDoes(tester, () async {});

    expect(key('client-dashboard-greeting'), findsOneWidget);
  });
}
