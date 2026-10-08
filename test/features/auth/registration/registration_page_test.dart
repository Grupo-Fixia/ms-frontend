import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/core/widgets/technician_steps.dart';
import 'package:ms_frontend/features/auth/registration/application/register_account.dart';
import 'package:ms_frontend/features/auth/registration/domain/account_role.dart';
import 'package:ms_frontend/features/auth/registration/domain/document_type.dart';
import 'package:ms_frontend/features/auth/registration/domain/registration_exceptions.dart';
import 'package:ms_frontend/features/auth/registration/presentation/registration_page.dart';
import 'package:ms_frontend/features/auth/registration/presentation/widgets/technician_registration_extras.dart';

import 'fake_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeAccountRegistrationRepository repository, {
  Size size = const Size(1024, 2000),
  AccountRole role = AccountRole.client,
  VoidCallback? onGoToLogin,
  VoidCallback? onSwitchRole,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: RegistrationPage(
        registerAccount: RegisterAccount(repository),
        role: role,
        onGoToLogin: onGoToLogin,
        onSwitchRole: onSwitchRole,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String name) => find.byKey(ValueKey('registration-$name-field'));

final _submitButton = find.byKey(const ValueKey('registration-submit'));

Future<void> _selectDocumentType(WidgetTester tester, DocumentType type) async {
  await tester.tap(_field('documentType'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(type.label).last);
  await tester.pumpAndSettle();
}

EditableText _editable(WidgetTester tester, String field) =>
    tester.widget<EditableText>(
      find.descendant(of: _field(field), matching: find.byType(EditableText)),
    );

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(_field('firstName'), 'Ana');
  await tester.enterText(_field('lastName'), 'Pérez');
  await _selectDocumentType(tester, DocumentType.cc);
  await tester.enterText(_field('documentNumber'), '1020304050');
  await tester.enterText(_field('email'), 'ana@fixia.com');
  await tester.enterText(_field('phone'), '3001234567');
  await tester.enterText(_field('password'), 'Segura123');
  await tester.enterText(_field('confirmPassword'), 'Segura123');
  await tester.ensureVisible(
    find.byKey(const ValueKey('registration-consent-checkbox')),
  );
  await tester.tap(find.byKey(const ValueKey('registration-consent-checkbox')));
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
    await _pump(tester, FakeAccountRegistrationRepository());

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
      FakeAccountRegistrationRepository(),
      size: const Size(360, 1600),
    );

    final firstName = tester.getTopLeft(_field('firstName'));
    final lastName = tester.getTopLeft(_field('lastName'));
    expect(lastName.dy, greaterThan(firstName.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('con el formulario vacío no envía y marca qué corregir',
      (tester) async {
    final repository = FakeAccountRegistrationRepository();
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
    await _pump(tester, FakeAccountRegistrationRepository());

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
      find.text('Usa entre 8 y 20 caracteres, con letras y números.'),
      findsOneWidget,
    );
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
  });

  testWidgets('tocar un campo solo marca el error de ese campo',
      (tester) async {
    await _pump(tester, FakeAccountRegistrationRepository());

    await tester.enterText(_field('email'), 'ana@');
    await tester.pump();

    expect(
      find.text('Ingresa un correo válido, por ejemplo nombre@correo.com.'),
      findsOneWidget,
    );
    expect(find.text('Ingresa tu nombre.'), findsNothing);
    expect(find.text('Ingresa tu teléfono.'), findsNothing);
    expect(find.text('Selecciona tu tipo de documento.'), findsNothing);
    expect(
      find.text('Debes aceptar el tratamiento de datos para crear la cuenta.'),
      findsNothing,
    );
  });

  testWidgets('con cédula el documento solo acepta números', (tester) async {
    await _pump(tester, FakeAccountRegistrationRepository());

    await _selectDocumentType(tester, DocumentType.cc);
    await tester.enterText(_field('documentNumber'), 'AB12.34 56');
    await tester.pump();

    expect(_editable(tester, 'documentNumber').controller.text, '123456');
  });

  testWidgets('con pasaporte acepta letras y al cambiar a cédula las quita',
      (tester) async {
    await _pump(tester, FakeAccountRegistrationRepository());

    await _selectDocumentType(tester, DocumentType.passport);
    await tester.enterText(_field('documentNumber'), 'AB123');
    await tester.pump();
    expect(_editable(tester, 'documentNumber').controller.text, 'AB123');

    await _selectDocumentType(tester, DocumentType.ce);
    expect(_editable(tester, 'documentNumber').controller.text, '123');
  });

  testWidgets('el teléfono solo acepta números y +', (tester) async {
    await _pump(tester, FakeAccountRegistrationRepository());

    await tester.enterText(_field('phone'), '+57 300-123 4567');
    await tester.pump();

    expect(_editable(tester, 'phone').controller.text, '+573001234567');
  });

  testWidgets('cada contraseña tiene su propio botón de ojo', (tester) async {
    await _pump(tester, FakeAccountRegistrationRepository());

    expect(_editable(tester, 'password').obscureText, isTrue);
    expect(_editable(tester, 'confirmPassword').obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar confirmación'));
    await tester.pump();
    expect(_editable(tester, 'confirmPassword').obscureText, isFalse);
    expect(_editable(tester, 'password').obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(_editable(tester, 'password').obscureText, isFalse);
  });

  testWidgets('cambiar la contraseña vuelve a comparar la confirmación',
      (tester) async {
    await _pump(tester, FakeAccountRegistrationRepository());

    await tester.enterText(_field('password'), 'Segura123');
    await tester.enterText(_field('confirmPassword'), 'Segura123');
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden.'), findsNothing);

    await tester.enterText(_field('password'), 'Segura1234');
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
  });

  testWidgets('cada campo muestra su ícono', (tester) async {
    await _pump(tester, FakeAccountRegistrationRepository());

    for (final icon in [
      Icons.person_outline,
      Icons.badge_outlined,
      Icons.numbers,
      Icons.email_outlined,
      Icons.phone_outlined,
      Icons.lock_outline,
    ]) {
      expect(find.byIcon(icon), findsWidgets, reason: '$icon');
    }
  });

  testWidgets('con datos válidos crea la cuenta y muestra el siguiente paso',
      (tester) async {
    final repository = FakeAccountRegistrationRepository();
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
      find.byKey(const ValueKey('registration-success')),
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
    final repository = FakeAccountRegistrationRepository(pending: pending);
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
    final repository = FakeAccountRegistrationRepository(
      failure: const RegistrationFailure(
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

  testWidgets('si la cuenta ya existe lo dice debajo del correo y el documento',
      (tester) async {
    const message = 'Ya existe una cuenta con este correo o documento.';
    final repository = FakeAccountRegistrationRepository(
      failure: const RegistrationFailure(
        'Ya existe una cuenta',
        isAccountConflict: true,
        fieldErrors: {'email': message, 'documentNumber': message},
      ),
    );
    await _pump(tester, repository);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: _field('email'), matching: find.text(message)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _field('documentNumber'),
        matching: find.text(message),
      ),
      findsOneWidget,
    );
    // Sin aviso rojo arriba ni diálogo: el error está en los campos.
    expect(
      find.byKey(const ValueKey('registration-error')),
      findsNothing,
    );
    expect(find.byType(AlertDialog), findsNothing);

    // Al cambiar el correo desaparece su aviso.
    await tester.enterText(_field('email'), 'otra@fixia.com');
    await tester.pump();
    expect(
      find.descendant(of: _field('email'), matching: find.text(message)),
      findsNothing,
    );
  });

  testWidgets('otros errores se muestran arriba del formulario y se cierran',
      (tester) async {
    final repository = FakeAccountRegistrationRepository(
      failure: const RegistrationFailure(
        'No pudimos conectar con Fixia.',
      ),
    );
    await _pump(tester, repository);

    await _fillValidForm(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    final banner = find.byKey(const ValueKey('registration-error'));
    expect(banner, findsOneWidget);
    expect(find.text('No pudimos conectar con Fixia.'), findsOneWidget);
    // Queda encima del primer campo del formulario.
    expect(
      tester.getTopLeft(banner).dy,
      lessThan(tester.getTopLeft(_field('firstName')).dy),
    );

    await tester.tap(find.byTooltip('Cerrar aviso'));
    await tester.pump();
    expect(banner, findsNothing);
  });

  testWidgets('el enlace lleva al inicio de sesión cuando está disponible',
      (tester) async {
    var wentToLogin = false;
    await _pump(
      tester,
      FakeAccountRegistrationRepository(),
      onGoToLogin: () => wentToLogin = true,
    );

    await tester.ensureVisible(find.text('Inicia sesión'));
    await tester.tap(find.text('Inicia sesión'));
    expect(wentToLogin, isTrue);
  });

  group('registro de técnico', () {
    testWidgets('usa los textos del técnico y los mismos campos',
        (tester) async {
      await _pump(
        tester,
        FakeAccountRegistrationRepository(),
        role: AccountRole.technician,
      );

      expect(find.text('Crea tu cuenta de técnico'), findsOneWidget);
      expect(
        find.text('Regístrate para ofrecer tus servicios y conseguir '
            'clientes cerca de ti.'),
        findsOneWidget,
      );
      for (final field in [
        'firstName',
        'lastName',
        'documentType',
        'documentNumber',
        'email',
        'phone',
        'password',
        'confirmPassword',
      ]) {
        expect(_field(field), findsOneWidget, reason: field);
      }
      expect(
        find.byKey(const ValueKey('registration-consent-checkbox')),
        findsOneWidget,
      );
    });

    testWidgets('con datos válidos crea la cuenta y pide completar el perfil',
        (tester) async {
      final repository = FakeAccountRegistrationRepository();
      await _pump(tester, repository, role: AccountRole.technician);

      await _fillValidForm(tester);
      await _submit(tester);
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.saved?.consentAccepted, isTrue);
      expect(find.text('¡Tu cuenta de técnico fue creada!'), findsOneWidget);
      expect(
        find.text('Inicia sesión con ana@fixia.com para completar tu perfil '
            'profesional. Tu cuenta queda pendiente de verificación.'),
        findsOneWidget,
      );
    });

    testWidgets('si el registro falla lo muestra arriba del formulario',
        (tester) async {
      await _pump(
        tester,
        FakeAccountRegistrationRepository(
          failure: const RegistrationFailure('No disponible'),
        ),
        role: AccountRole.technician,
      );

      await _fillValidForm(tester);
      await _submit(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('registration-error')), findsOneWidget);
      expect(find.text('No disponible'), findsOneWidget);
    });
  });

  group('distintivos del registro de técnico', () {
    final badge = find.byKey(const ValueKey('technician-badge'));
    final steps = find.byKey(const ValueKey('technician-steps'));
    final benefits = find.byKey(const ValueKey('technician-benefits'));

    testWidgets('el cliente no ve etiqueta, pasos ni razones', (tester) async {
      await _pump(tester, FakeAccountRegistrationRepository());

      expect(badge, findsNothing);
      expect(steps, findsNothing);
      expect(benefits, findsNothing);
    });

    testWidgets('el técnico ve la etiqueta y los 3 pasos', (tester) async {
      await _pump(
        tester,
        FakeAccountRegistrationRepository(),
        role: AccountRole.technician,
      );

      expect(badge, findsOneWidget);
      expect(find.text('Cuenta de técnico'), findsOneWidget);
      expect(steps, findsOneWidget);
      for (final label in TechnicianSteps.labels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('en pantalla ancha las razones van al lado del formulario',
        (tester) async {
      await _pump(
        tester,
        FakeAccountRegistrationRepository(),
        role: AccountRole.technician,
      );

      expect(benefits, findsOneWidget);
      for (final reason in TechnicianBenefits.reasons) {
        expect(find.text(reason.title), findsOneWidget);
        expect(find.text(reason.text), findsOneWidget);
      }
      final panel = tester.getRect(benefits);
      final form = tester.getRect(_field('firstName'));
      expect(panel.right, lessThan(form.left));
    });

    for (final size in const [Size(320, 900), Size(375, 900)]) {
      testWidgets(
          'en celular de ${size.width.toInt()} px van arriba, cortas y sin '
          'desbordes', (tester) async {
        await _pump(
          tester,
          FakeAccountRegistrationRepository(),
          role: AccountRole.technician,
          size: size,
        );

        expect(tester.takeException(), isNull);
        expect(benefits, findsOneWidget);
        for (final reason in TechnicianBenefits.reasons) {
          expect(find.text(reason.title), findsOneWidget);
          expect(find.text(reason.text), findsNothing);
        }
        expect(
          tester.getRect(benefits).bottom,
          lessThan(tester.getRect(badge).top),
        );
      });
    }
  });

  group('enlace al otro tipo de cuenta', () {
    testWidgets('sin callback no se muestra', (tester) async {
      await _pump(tester, FakeAccountRegistrationRepository());

      expect(
        find.byKey(const ValueKey('registration-switch-role')),
        findsNothing,
      );
    });

    testWidgets('desde cliente lleva al registro de técnico', (tester) async {
      var switched = false;
      await _pump(
        tester,
        FakeAccountRegistrationRepository(),
        onSwitchRole: () => switched = true,
      );

      final link = find.byKey(const ValueKey('registration-switch-role'));
      await tester.ensureVisible(link);
      expect(find.text('Regístrate como técnico'), findsOneWidget);
      await tester.tap(link);
      expect(switched, isTrue);
    });

    testWidgets('desde técnico lleva al registro de cliente', (tester) async {
      var switched = false;
      await _pump(
        tester,
        FakeAccountRegistrationRepository(),
        role: AccountRole.technician,
        onSwitchRole: () => switched = true,
      );

      final link = find.byKey(const ValueKey('registration-switch-role'));
      await tester.ensureVisible(link);
      expect(find.text('Regístrate como cliente'), findsOneWidget);
      await tester.tap(link);
      expect(switched, isTrue);
    });
  });
}
