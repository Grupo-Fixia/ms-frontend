import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/client_registration/application/register_client.dart';
import 'package:ms_frontend/features/client_registration/domain/client_registration_exceptions.dart';
import 'package:ms_frontend/features/client_registration/domain/document_type.dart';
import 'package:ms_frontend/features/client_registration/presentation/client_registration_page.dart';

import 'fake_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeClientRegistrationRepository repository, {
  Size size = const Size(1024, 2000),
  VoidCallback? onGoToLogin,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: ClientRegistrationPage(
        registerClient: RegisterClient(repository),
        onGoToLogin: onGoToLogin,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String name) => find.byKey(ValueKey('client-$name-field'));

final _submitButton = find.byKey(const ValueKey('client-registration-submit'));

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(_field('firstName'), 'Ana');
  await tester.enterText(_field('lastName'), 'Pérez');
  await tester.tap(_field('documentType'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(DocumentType.cc.label).last);
  await tester.pumpAndSettle();
  await tester.enterText(_field('documentNumber'), '1020304050');
  await tester.enterText(_field('email'), 'ana@fixia.com');
  await tester.enterText(_field('phone'), '3001234567');
  await tester.enterText(_field('password'), 'Segura123');
  await tester.enterText(_field('confirmPassword'), 'Segura123');
  await tester.ensureVisible(
    find.byKey(const ValueKey('client-consent-checkbox')),
  );
  await tester.tap(find.byKey(const ValueKey('client-consent-checkbox')));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_submitButton);
  await tester.tap(_submitButton);
  await tester.pump();
}

void main() {
  testWidgets('muestra los datos de identificación, contacto y consentimiento',
      (tester) async {
    await _pump(tester, FakeClientRegistrationRepository());

    for (final label in [
      'Nombres',
      'Apellidos',
      'Tipo de documento',
      'Número de documento',
      'Correo electrónico',
      'Teléfono celular',
      'Contraseña',
      'Confirmar contraseña',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.textContaining('versión v1.0'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsNothing);
  });

  testWidgets('en pantallas angostas apila nombres y apellidos',
      (tester) async {
    await _pump(
      tester,
      FakeClientRegistrationRepository(),
      size: const Size(360, 1600),
    );

    final firstName = tester.getTopLeft(_field('firstName'));
    final lastName = tester.getTopLeft(_field('lastName'));
    expect(lastName.dy, greaterThan(firstName.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('con el formulario vacío no envía y marca qué corregir',
      (tester) async {
    final repository = FakeClientRegistrationRepository();
    await _pump(tester, repository);

    await _submit(tester);

    expect(repository.calls, 0);
    expect(find.text('Ingresa tu nombre.'), findsOneWidget);
    expect(find.text('Selecciona tu tipo de documento.'), findsOneWidget);
    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(
      find.text('Debes aceptar el tratamiento de datos para crear la cuenta.'),
      findsOneWidget,
    );
  });

  testWidgets('valida formatos mientras el usuario escribe', (tester) async {
    await _pump(tester, FakeClientRegistrationRepository());

    await tester.enterText(_field('email'), 'ana@');
    await tester.enterText(_field('phone'), '12');
    await tester.enterText(_field('password'), 'solotexto');
    await tester.enterText(_field('confirmPassword'), 'otra');
    await tester.pump();

    expect(
      find.text('Ingresa un correo válido, por ejemplo nombre@correo.com.'),
      findsOneWidget,
    );
    expect(find.text('Ingresa solo números (7 a 15 dígitos).'), findsOneWidget);
    expect(
      find.text('Usa entre 8 y 72 caracteres, con letras y números.'),
      findsOneWidget,
    );
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
  });

  testWidgets('el botón del ojo muestra y oculta la contraseña',
      (tester) async {
    await _pump(tester, FakeClientRegistrationRepository());

    EditableText password() => tester.widget<EditableText>(
          find.descendant(
            of: _field('password'),
            matching: find.byType(EditableText),
          ),
        );

    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });

  testWidgets('con datos válidos crea la cuenta y muestra el siguiente paso',
      (tester) async {
    final repository = FakeClientRegistrationRepository();
    var wentToLogin = false;
    await _pump(tester, repository, onGoToLogin: () => wentToLogin = true);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(repository.saved?.documentType, DocumentType.cc);
    expect(repository.saved?.consentAccepted, isTrue);
    expect(repository.saved?.consentAcceptedAt, isNotNull);
    expect(
      find.byKey(const ValueKey('client-registration-success')),
      findsOneWidget,
    );
    expect(find.text('Ya puedes iniciar sesión con ana@fixia.com.'),
        findsOneWidget);

    await tester.tap(find.text('Ir a iniciar sesión'));
    expect(wentToLogin, isTrue);
  });

  testWidgets('bloquea el botón mientras envía (sin doble envío)',
      (tester) async {
    final pending = Completer<void>();
    final repository = FakeClientRegistrationRepository(pending: pending);
    await _pump(tester, repository);

    await _fillValidForm(tester);
    await _submit(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(_submitButton).onPressed, isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
  });

  testWidgets('muestra debajo del campo el error que devuelve el backend',
      (tester) async {
    final repository = FakeClientRegistrationRepository(
      failure: const ClientRegistrationFailure(
        'Hay datos que debe corregir',
        fieldErrors: {'email': 'El correo electrónico no es válido'},
      ),
    );
    await _pump(tester, repository);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pump();

    expect(find.text('El correo electrónico no es válido'), findsOneWidget);
    expect(find.text('Hay datos que debe corregir'), findsOneWidget);

    await tester.enterText(_field('email'), 'ana.perez@fixia.com');
    await tester.pump();
    expect(find.text('El correo electrónico no es válido'), findsNothing);
  });

  testWidgets('el enlace lleva al inicio de sesión cuando está disponible',
      (tester) async {
    var wentToLogin = false;
    await _pump(
      tester,
      FakeClientRegistrationRepository(),
      onGoToLogin: () => wentToLogin = true,
    );

    await tester.ensureVisible(find.text('Inicia sesión'));
    await tester.tap(find.text('Inicia sesión'));
    expect(wentToLogin, isTrue);
  });
}
