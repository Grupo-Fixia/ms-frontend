import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/auth/application/login_user.dart';
import 'package:ms_frontend/features/auth/application/session_store.dart';
import 'package:ms_frontend/features/auth/domain/auth_exceptions.dart';
import 'package:ms_frontend/features/auth/presentation/login_page.dart';

import 'fake_auth_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeAuthRepository repository, {
  Size size = const Size(1024, 1000),
  VoidCallback? onLoggedIn,
  VoidCallback? onGoToRegistration,
  SessionStore? store,
  FakeSessionStorage? storage,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: LoginPage(
        loginUser: LoginUser(
          repository,
          store ?? SessionStore(),
          storage ?? FakeSessionStorage(),
        ),
        onLoggedIn: onLoggedIn,
        onGoToRegistration: onGoToRegistration,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _email = find.byKey(const ValueKey('login-email-field'));
final _password = find.byKey(const ValueKey('login-password-field'));
final _submitButton = find.byKey(const ValueKey('login-submit'));
final _rememberCheckbox = find.byKey(const ValueKey('login-remember-checkbox'));

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(_email, 'ana@fixia.com');
  await tester.enterText(_password, 'Segura123');
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(_submitButton);
  await tester.pump();
}

bool _passwordIsObscured(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(of: _password, matching: find.byType(EditableText)),
    )
    .obscureText;

void main() {
  testWidgets('los campos llevan el ícono de correo y de contraseña',
      (tester) async {
    await _pump(tester, FakeAuthRepository());

    expect(
      find.descendant(
        of: _email,
        matching: find.byIcon(Icons.mail_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _password,
        matching: find.byIcon(Icons.lock_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('muestra "Mantener sesión iniciada" desmarcado por defecto',
      (tester) async {
    await _pump(tester, FakeAuthRepository());

    expect(find.text('Mantener sesión iniciada'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(_rememberCheckbox).value, isFalse);
  });

  testWidgets('marcada, la casilla guarda el refresh token al iniciar sesión',
      (tester) async {
    final storage = FakeSessionStorage();
    await _pump(tester, FakeAuthRepository(), storage: storage);

    await tester.tap(_rememberCheckbox);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(_rememberCheckbox).value, isTrue);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(storage.refreshToken, fixtureSession.refreshToken);
  });

  testWidgets('sin marcar la casilla no se guarda ningún token',
      (tester) async {
    final storage = FakeSessionStorage();
    await _pump(tester, FakeAuthRepository(), storage: storage);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(storage.refreshToken, isNull);
  });

  testWidgets('la casilla se bloquea mientras se envía', (tester) async {
    final pending = Completer<void>();
    await _pump(tester, FakeAuthRepository(pendingLogin: pending));

    await _fillValidForm(tester);
    await _submit(tester);

    expect(
      tester.widget<CheckboxListTile>(_rememberCheckbox).enabled,
      isFalse,
    );

    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('muestra el encabezado, los campos y el botón', (tester) async {
    await _pump(tester, FakeAuthRepository());

    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(_email, findsOneWidget);
    expect(_password, findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('con los campos vacíos muestra los errores y no envía nada',
      (tester) async {
    final repository = FakeAuthRepository();
    await _pump(tester, repository);

    await _submit(tester);

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('rechaza un correo sin forma de correo', (tester) async {
    final repository = FakeAuthRepository();
    await _pump(tester, repository);

    await tester.enterText(_email, 'ana');
    await tester.enterText(_password, 'Segura123');
    await _submit(tester);

    expect(find.textContaining('Ingresa un correo válido'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('con datos válidos inicia sesión y avisa con onLoggedIn',
      (tester) async {
    final repository = FakeAuthRepository();
    final store = SessionStore();
    var loggedIn = 0;
    await _pump(
      tester,
      repository,
      store: store,
      onLoggedIn: () => loggedIn++,
    );

    await tester.enterText(_email, '  ana@fixia.com ');
    await tester.enterText(_password, 'Segura123');
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'ana@fixia.com');
    expect(repository.lastPassword, 'Segura123');
    expect(store.isAuthenticated, isTrue);
    expect(loggedIn, 1);
  });

  testWidgets('con credenciales inválidas muestra el mensaje y no avanza',
      (tester) async {
    final repository = FakeAuthRepository(
      loginFailure: const AuthFailure('Credenciales inválidas'),
    );
    var loggedIn = 0;
    await _pump(tester, repository, onLoggedIn: () => loggedIn++);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Credenciales inválidas'), findsOneWidget);
    expect(loggedIn, 0);
    // El formulario sigue disponible para reintentar.
    expect(
      tester.widget<FilledButton>(_submitButton).onPressed,
      isNotNull,
    );
  });

  testWidgets('muestra debajo de cada campo los errores del backend',
      (tester) async {
    final repository = FakeAuthRepository(
      loginFailure: const AuthFailure(
        'Hay datos que debe corregir',
        fieldErrors: {'email': 'El correo electrónico no es válido'},
      ),
    );
    await _pump(tester, repository);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('El correo electrónico no es válido'), findsOneWidget);

    // Al editar el campo se descarta el error del backend.
    await tester.enterText(_email, 'otra@fixia.com');
    await tester.pumpAndSettle();
    expect(find.text('El correo electrónico no es válido'), findsNothing);
  });

  testWidgets('mientras envía bloquea el botón y muestra el progreso',
      (tester) async {
    final pending = Completer<void>();
    final repository = FakeAuthRepository(pendingLogin: pending);
    await _pump(tester, repository);

    await _fillValidForm(tester);
    await _submit(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);

    await tester.tap(_submitButton, warnIfMissed: false);
    await tester.pump();
    expect(repository.loginCalls, 1);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Enter en la contraseña envía el formulario', (tester) async {
    final repository = FakeAuthRepository();
    await _pump(tester, repository);

    await _fillValidForm(tester);
    await tester.tap(_password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
  });

  testWidgets('el ojo muestra y oculta la contraseña', (tester) async {
    await _pump(tester, FakeAuthRepository());
    expect(_passwordIsObscured(tester), isTrue);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(_passwordIsObscured(tester), isFalse);

    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();
    expect(_passwordIsObscured(tester), isTrue);
  });

  testWidgets('el enlace lleva al registro y solo existe si hay destino',
      (tester) async {
    var goToRegistration = 0;
    await _pump(
      tester,
      FakeAuthRepository(),
      onGoToRegistration: () => goToRegistration++,
    );

    await tester.tap(find.text('Crear cuenta'));
    expect(goToRegistration, 1);

    await _pump(tester, FakeAuthRepository());
    expect(find.text('Crear cuenta'), findsNothing);
  });

  testWidgets('en un celular angosto no se desborda', (tester) async {
    await _pump(
      tester,
      FakeAuthRepository(),
      size: const Size(320, 640),
      onGoToRegistration: () {},
    );

    expect(tester.takeException(), isNull);
    expect(_submitButton, findsOneWidget);
  });
}
