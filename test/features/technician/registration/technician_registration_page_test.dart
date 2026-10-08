import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/core/models/document_type.dart';
import 'package:ms_frontend/features/technician/registration/application/register_technician.dart';
import 'package:ms_frontend/features/technician/registration/domain/technician_registration_exceptions.dart';
import 'package:ms_frontend/features/technician/registration/domain/technician_profession.dart';
import 'package:ms_frontend/features/technician/registration/presentation/technician_registration_page.dart';

import 'fake_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTechnicianRegistrationRepository repository, {
  VoidCallback? onGoToLogin,
  VoidCallback? onGoToClientRegistration,
}) async {
  tester.view.physicalSize = const Size(1024, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: TechnicianRegistrationPage(
        registerTechnician: RegisterTechnician(repository),
        onGoToLogin: onGoToLogin,
        onGoToClientRegistration: onGoToClientRegistration,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String name) => find.byKey(ValueKey('technician-$name-field'));

final _submitButton =
    find.byKey(const ValueKey('technician-registration-submit'));

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(_field('firstName'), 'Ana');
  await tester.enterText(_field('lastName'), 'Pérez');
  await tester.tap(_field('profession'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(TechnicianProfession.electrical.label).last);
  await tester.pumpAndSettle();
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
    find.byKey(const ValueKey('technician-consent-checkbox')),
  );
  await tester.tap(
    find.byKey(const ValueKey('technician-consent-checkbox')),
  );
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_submitButton);
  await tester.tap(_submitButton);
  await tester.pump();
}

void main() {
  testWidgets('muestra campos y política de registro de técnico', (
    tester,
  ) async {
    await _pump(tester, FakeTechnicianRegistrationRepository());

    for (final label in [
      'Tipo de cuenta',
      'Profesión',
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
    expect(find.textContaining('v1.0'), findsOneWidget);
  });

  testWidgets(
      'usa iconos alineados al registro cliente y permite volver al login',
      (tester) async {
    var wentToLogin = false;
    await _pump(
      tester,
      FakeTechnicianRegistrationRepository(),
      onGoToLogin: () => wentToLogin = true,
    );

    for (final icon in [
      Icons.person_outline,
      Icons.badge_outlined,
      Icons.numbers,
      Icons.email_outlined,
      Icons.phone_outlined,
      Icons.lock_outline,
    ]) {
      expect(find.byIcon(icon), findsWidgets);
    }

    final loginLink = find.byKey(const ValueKey('technician-go-to-login'));
    await tester.ensureVisible(loginLink);
    await tester.tap(loginLink);
    expect(wentToLogin, isTrue);
  });

  testWidgets('permite ir al registro de usuario', (tester) async {
    var wentToClientRegistration = false;
    await _pump(
      tester,
      FakeTechnicianRegistrationRepository(),
      onGoToClientRegistration: () => wentToClientRegistration = true,
    );

    final registrationLink =
        find.byKey(const ValueKey('technician-go-to-client-registration'));
    await tester.ensureVisible(registrationLink);
    await tester.tap(registrationLink);

    expect(find.text('Regístrate como usuario'), findsOneWidget);
    expect(wentToClientRegistration, isTrue);
  });

  testWidgets('valida correo y confirmación antes de enviar', (tester) async {
    final repository = FakeTechnicianRegistrationRepository();
    await _pump(tester, repository);

    await tester.enterText(_field('email'), 'ana@');
    await tester.enterText(_field('password'), 'Segura123');
    await tester.enterText(_field('confirmPassword'), 'Otra1234');
    await tester.pump();

    expect(
      find.text('Ingresa un correo válido, por ejemplo nombre@correo.com.'),
      findsOneWidget,
    );
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);

    await _submit(tester);
    expect(repository.calls, 0);
  });

  testWidgets('con formulario vacío no envía y marca campos obligatorios', (
    tester,
  ) async {
    final repository = FakeTechnicianRegistrationRepository();
    await _pump(tester, repository);

    await _submit(tester);

    expect(repository.calls, 0);
    expect(find.text('Ingresa tu nombre.'), findsOneWidget);
    expect(find.text('Selecciona tu profesión.'), findsOneWidget);
    expect(find.text('Selecciona tu tipo de documento.'), findsOneWidget);
    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(
      find.text('Debes aceptar el tratamiento de datos para crear la cuenta.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra el error controlado de conexión al enviar', (
    tester,
  ) async {
    final repository = FakeTechnicianRegistrationRepository(
      failure: const TechnicianRegistrationFailure(
        'No fue posible conectar con el servidor. Inténtalo de nuevo.',
      ),
    );
    await _pump(tester, repository);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(repository.saved?.profession, TechnicianProfession.electrical);
    expect(repository.saved?.profession.categoryCode, 'ELECTRICAL');
    expect(
      find.text('No fue posible conectar con el servidor. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });
}
