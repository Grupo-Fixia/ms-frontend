import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/auth/login/application/logout_user.dart';
import 'package:ms_frontend/features/auth/login/application/session_store.dart';
import 'package:ms_frontend/features/auth/login/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/login/presentation/session_page.dart';

import 'fake_auth_repository.dart';

Future<SessionStore> _pump(
  WidgetTester tester,
  FakeAuthRepository repository, {
  VoidCallback? onLoggedOut,
}) async {
  tester.view.physicalSize = const Size(1024, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = SessionStore()..start(fixtureSession, fixtureProfile);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: SessionPage(
        store: store,
        logoutUser: LogoutUser(repository, store, FakeSessionStorage()),
        onLoggedOut: onLoggedOut,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

final _logoutButton = find.byKey(const ValueKey('session-logout'));

void main() {
  testWidgets('muestra el nombre, el correo y el rol de la cuenta',
      (tester) async {
    await _pump(tester, FakeAuthRepository());

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@fixia.com'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
  });

  testWidgets('cerrar sesión llama al backend, limpia la sesión y avisa',
      (tester) async {
    final repository = FakeAuthRepository();
    var loggedOut = 0;
    final store = await _pump(
      tester,
      repository,
      onLoggedOut: () => loggedOut++,
    );

    await tester.tap(_logoutButton);
    await tester.pumpAndSettle();

    expect(repository.loggedOutSession, fixtureSession);
    expect(store.isAuthenticated, isFalse);
    expect(loggedOut, 1);
  });

  testWidgets('si el backend falla igual sale de la sesión', (tester) async {
    final repository = FakeAuthRepository(
      logoutFailure: const AuthFailure('sin conexión'),
    );
    var loggedOut = 0;
    final store = await _pump(
      tester,
      repository,
      onLoggedOut: () => loggedOut++,
    );

    await tester.tap(_logoutButton);
    await tester.pumpAndSettle();

    expect(store.isAuthenticated, isFalse);
    expect(loggedOut, 1);
  });

  testWidgets('mientras cierra bloquea el botón y evita un segundo cierre',
      (tester) async {
    final pending = Completer<void>();
    final repository = FakeAuthRepository(pendingLogout: pending);
    await _pump(tester, repository);

    await tester.tap(_logoutButton);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(_logoutButton).onPressed, isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.logoutCalls, 1);
  });
}
