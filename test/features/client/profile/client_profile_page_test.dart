import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/auth/login/domain/user_profile.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_rules.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_update.dart';
import 'package:ms_frontend/features/client/profile/presentation/client_profile_page.dart';

const _profile = UserProfile(
  id: 'client-1',
  email: 'ana@fixia.com',
  firstName: 'Ana',
  lastName: 'Pérez',
  role: UserRole.client,
);

Future<void> _pump(
  WidgetTester tester, {
  UserProfile profile = _profile,
  ValueChanged<ClientProfileUpdate>? onSaved,
  Size size = const Size(390, 844),
  String? address,
  String? city,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: ClientProfilePage(
        firstName: profile.firstName,
        lastName: profile.lastName,
        email: profile.email,
        phone: profile.phone,
        address: address,
        city: city,
        onSaved: onSaved,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openEdit(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('client-profile-edit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('consulta los datos del cliente y deja el correo de solo lectura',
      (tester) async {
    await _pump(tester);

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-profile-full-name')),
      findsOneWidget,
    );
    expect(find.text('ana@fixia.com'), findsOneWidget);
    expect(find.text('No registrado'), findsOneWidget);
    // Sin datos de ejemplo: ni métodos de pago ni saldo inventados.
    expect(find.text('Débito •••• 4582'), findsNothing);
    expect(find.text('Datos de demostración'), findsNothing);
    expect(find.byKey(const ValueKey('client-profile-wallet')), findsNothing);
    expect(find.byKey(const ValueKey('client-profile-payments-note')),
        findsOneWidget);
    expect(find.text('–'), findsNWidgets(3));
    // En celular «Mi perfil» va dentro de «Más».
    expect(
      find.byKey(const ValueKey('client-nav-mas')),
      findsOneWidget,
    );

    final editButton = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('client-profile-edit')),
    );
    expect(editButton.onPressed, isNotNull);
    await _openEdit(tester);
    final emailField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('client-profile-email')),
        matching: find.byType(EditableText),
      ),
    );
    expect(emailField.readOnly, isTrue);
    expect(find.byKey(const ValueKey('client-profile-first-name')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('client-profile-last-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('client-profile-phone')), findsOneWidget);
  });

  testWidgets('valida nombre, apellido y teléfono antes de guardar',
      (tester) async {
    var saveCalls = 0;
    await _pump(tester, onSaved: (_) => saveCalls++);
    await _openEdit(tester);

    await tester.enterText(
      find.byKey(const ValueKey('client-profile-first-name')),
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-profile-last-name')),
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-profile-phone')),
      '12ab',
    );
    await _tap(tester, find.byKey(const ValueKey('client-profile-save')));

    expect(find.text('El nombre es obligatorio.'), findsOneWidget);
    expect(find.text('El apellido es obligatorio.'), findsOneWidget);
    expect(
      find.text('Ingresa un teléfono válido de 7 a 15 dígitos.'),
      findsOneWidget,
    );
    expect(saveCalls, 0);
  });

  testWidgets('guarda en memoria y comunica que aún no sincroniza',
      (tester) async {
    ClientProfileUpdate? saved;
    await _pump(tester, onSaved: (update) => saved = update);
    await _openEdit(tester);

    await tester.enterText(
      find.byKey(const ValueKey('client-profile-first-name')),
      'Lucía',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-profile-last-name')),
      'Gómez',
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-profile-phone')),
      '+573001112233',
    );
    await _tap(tester, find.byKey(const ValueKey('client-profile-save')));

    expect(saved?.firstName, 'Lucía');
    expect(saved?.lastName, 'Gómez');
    expect(saved?.phone, '+573001112233');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('client-profile-full-name')),
          )
          .data,
      'Lucía Gómez',
    );
    expect(find.byKey(const ValueKey('client-profile-saved-local')),
        findsOneWidget);
  });

  testWidgets('permite cancelar sin alterar los datos visibles',
      (tester) async {
    await _pump(tester);
    await _openEdit(tester);
    await tester.enterText(
      find.byKey(const ValueKey('client-profile-first-name')),
      'Otro',
    );
    await _tap(tester, find.byKey(const ValueKey('client-profile-cancel')));

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('client-profile-full-name')),
          )
          .data,
      'Ana Pérez',
    );
    expect(
        find.byKey(const ValueKey('client-profile-summary')), findsOneWidget);
  });

  testWidgets('el botón Inicio delega la navegación al dashboard',
      (tester) async {
    var homeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: ClientProfilePage(
          firstName: _profile.firstName,
          lastName: _profile.lastName,
          email: _profile.email,
          onOpenHome: () => homeCalls++,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('client-nav-inicio')),
    );

    expect(homeCalls, 1);
  });

  testWidgets('no desborda en móvil estrecho', (tester) async {
    await _pump(tester, size: const Size(320, 812));
    await _tap(tester, find.byKey(const ValueKey('client-profile-edit')));
    expect(tester.takeException(), isNull);
  });

  group('dirección y ciudad (GC-317)', () {
    testWidgets('sin dirección lo dice', (tester) async {
      await _pump(tester);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('client-profile-address-row')),
              matching: find.text('No registrada')),
          findsOneWidget);
    });

    testWidgets('muestra la guardada y permite cambiarla', (tester) async {
      ClientProfileUpdate? saved;
      await _pump(
        tester,
        address: 'Calle 45 # 13-20',
        city: 'Bogotá',
        onSaved: (update) => saved = update,
        size: const Size(1280, 1100),
      );
      expect(find.text('Calle 45 # 13-20, Bogotá'), findsOneWidget);

      await _openEdit(tester);
      expect(find.text('Bogotá'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('client-profile-phone')),
        '+573001112233',
      );
      await tester.enterText(
        find.byKey(const ValueKey('client-profile-address')),
        '  Carrera 7 # 72-10  ',
      );
      await _tap(tester, find.byKey(const ValueKey('client-profile-city')));
      await tester.tap(find.text('Cali').last);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('client-profile-save')));

      expect(saved?.address, 'Carrera 7 # 72-10');
      expect(saved?.city, 'Cali');
      expect(find.text('Carrera 7 # 72-10, Cali'), findsOneWidget);
    });

    testWidgets('una ciudad fuera de la lista avisa', (tester) async {
      await _pump(tester, city: 'dsa', size: const Size(1280, 1100));
      await _openEdit(tester);
      expect(find.byKey(const ValueKey('client-profile-city-unknown')),
          findsOneWidget);
    });

    test('la dirección no supera 255 caracteres', () {
      expect(ClientProfileRules.address('a' * 255), isNull);
      expect(ClientProfileRules.address('a' * 256), isNotNull);
      expect(ClientProfileRules.address(null), isNull);
    });
  });
}
