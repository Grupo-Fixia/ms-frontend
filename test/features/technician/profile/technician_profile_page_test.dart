import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/profile/application/get_technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/application/update_technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile_exceptions.dart';
import 'package:ms_frontend/features/technician/profile/domain/verification_status.dart';
import 'package:ms_frontend/features/technician/profile/presentation/technician_profile_page.dart';

import 'fake_repository.dart';
import 'fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeTechnicianProfileRepository repository, {
  Size size = const Size(1024, 2000),
  String? firstName = 'Luis',
  Future<void> Function()? onLogout,
  VoidCallback? onSessionExpired,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FixiaTheme.light,
      home: TechnicianProfilePage(
        getProfile: GetTechnicianProfile(repository),
        updateProfile: UpdateTechnicianProfile(repository),
        firstName: firstName,
        onLogout: onLogout,
        onSessionExpired: onSessionExpired,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

/// Título del formulario (su texto coincide con el del paso 2).
String? _title(WidgetTester tester) =>
    tester.widget<Text>(_key('technician-profile-title')).data;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await _tap(tester, _key('profile-category-PLUMBING'));
  await _tap(tester, _key('profile-category-MAINTENANCE'));
  await tester.enterText(_key('profile-years-field'), '8');
  await tester.enterText(
    _key('profile-description-field'),
    'Plomero con experiencia en redes residenciales.',
  );
  await tester.pump();
}

void main() {
  group('perfil incompleto (paso 2)', () {
    testWidgets('muestra "Completa tu perfil" con el paso 2 activo',
        (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: emptyProfile),
      );

      expect(_title(tester), 'Completa tu perfil profesional');
      expect(_key('technician-steps'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Paso 2: Completa tu perfil profesional '
            '(actual)'),
        findsOneWidget,
      );
      for (final category in ServiceCategory.values) {
        expect(_key('profile-category-${category.apiValue}'), findsOneWidget);
      }
      // Completar el perfil es obligatorio: no hay "Cancelar".
      expect(_key('profile-cancel'), findsNothing);
    });

    testWidgets('sin datos no guarda y marca qué falta', (tester) async {
      final repository = FakeTechnicianProfileRepository(profile: emptyProfile);
      await _pump(tester, repository);

      await _tap(tester, _key('profile-save'));

      expect(repository.updateCalls, 0);
      expect(find.text('Elige al menos una categoría.'), findsOneWidget);
      expect(find.text('Indica tus años de experiencia.'), findsOneWidget);
      expect(
        find.text('Cuéntales a los clientes qué haces y en qué tienes '
            'experiencia.'),
        findsOneWidget,
      );
    });

    testWidgets('los años solo aceptan números entre 0 y 80', (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: emptyProfile),
      );

      await tester.enterText(_key('profile-years-field'), 'a9');
      await tester.pump();
      final field = tester.widget<EditableText>(
        find.descendant(
          of: _key('profile-years-field'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, '9');

      await tester.enterText(_key('profile-years-field'), '95');
      await tester.pump();
      expect(find.text('Ingresa un número entre 0 y 80.'), findsOneWidget);
    });

    testWidgets('al guardar pasa al resumen con la verificación (paso 3)',
        (tester) async {
      final repository = FakeTechnicianProfileRepository(profile: emptyProfile);
      await _pump(tester, repository);

      await _fillValidForm(tester);
      await _tap(tester, _key('profile-save'));

      expect(repository.updateCalls, 1);
      expect(repository.lastUpdate?.categories, {
        ServiceCategory.plumbing,
        ServiceCategory.maintenance,
      });
      expect(repository.lastUpdate?.yearsOfExperience, 8);
      expect(_key('profile-saved'), findsOneWidget);
      expect(_key('technician-profile-summary'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Paso 3: Verificación de Fixia (actual)'),
        findsOneWidget,
      );
    });

    testWidgets('quitar una categoría elegida la deselecciona',
        (tester) async {
      final repository = FakeTechnicianProfileRepository(profile: emptyProfile);
      await _pump(tester, repository);

      await _fillValidForm(tester);
      await _tap(tester, _key('profile-category-MAINTENANCE'));
      await _tap(tester, _key('profile-save'));

      expect(repository.lastUpdate?.categories, {ServiceCategory.plumbing});
    });

    testWidgets('bloquea el botón mientras guarda', (tester) async {
      final pending = Completer<void>();
      final repository = FakeTechnicianProfileRepository(
        profile: emptyProfile,
        pendingUpdate: pending,
      );
      await _pump(tester, repository);
      await _fillValidForm(tester);

      await tester.ensureVisible(_key('profile-save'));
      await tester.tap(_key('profile-save'));
      await tester.pump();

      final button = tester.widget<FilledButton>(_key('profile-save'));
      expect(button.onPressed, isNull);
      pending.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('muestra los errores del backend arriba y por campo',
        (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(
          profile: emptyProfile,
          updateFailure: const TechnicianProfileFailure(
            'Revisa los datos marcados en el perfil.',
            fieldErrors: {
              'professionalDescription': 'La descripción es obligatoria',
            },
          ),
        ),
      );

      await _fillValidForm(tester);
      await _tap(tester, _key('profile-save'));

      expect(_key('profile-error'), findsOneWidget);
      expect(find.text('La descripción es obligatoria'), findsOneWidget);

      await _tap(tester, find.byTooltip('Cerrar aviso'));
      expect(_key('profile-error'), findsNothing);
    });
  });

  group('perfil completo', () {
    testWidgets('muestra el resumen con saludo, categorías y experiencia',
        (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: completeProfile()),
      );

      expect(find.text('Hola, Luis'), findsOneWidget);
      expect(find.text('Pendiente de verificación'), findsOneWidget);
      expect(_key('profile-summary-PLUMBING'), findsOneWidget);
      expect(_key('profile-summary-ELECTRICAL'), findsOneWidget);
      expect(_key('profile-summary-PAINTING'), findsNothing);
      expect(find.text('8 años'), findsOneWidget);
      expect(
        find.text('Plomero con experiencia en redes residenciales.'),
        findsOneWidget,
      );
      expect(_key('profile-saved'), findsNothing);
    });

    testWidgets('con 1 año lo dice en singular y sin nombre usa un título',
        (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: completeProfile(years: 1)),
        firstName: null,
      );

      expect(find.text('1 año'), findsOneWidget);
      expect(find.text('Tu perfil profesional'), findsOneWidget);
    });

    testWidgets('pendiente: dice que la solicitud está en revisión',
        (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: completeProfile()),
      );

      expect(_key('profile-verification-card'), findsOneWidget);
      expect(find.text('Tu solicitud está en revisión'), findsOneWidget);
      expect(_key('technician-steps'), findsOneWidget);
    });

    testWidgets('vencida: pide renovar la verificación', (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(
          profile: completeProfile(status: VerificationStatus.expired),
        ),
      );

      expect(find.text('Verificación vencida'), findsOneWidget);
      expect(find.text('Tu verificación venció'), findsOneWidget);
      expect(_key('technician-steps'), findsNothing);
    });

    testWidgets('un técnico verificado no ve los pasos', (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(
          profile: completeProfile(status: VerificationStatus.valid),
        ),
      );

      expect(find.text('Verificado'), findsOneWidget);
      expect(find.text('Tu cuenta de técnico está aprobada'), findsOneWidget);
      expect(_key('technician-steps'), findsNothing);
    });

    testWidgets('muestra la verificación rechazada', (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(
          profile: completeProfile(status: VerificationStatus.rejected),
        ),
      );

      expect(find.text('Verificación rechazada'), findsOneWidget);
      expect(find.text('Tu solicitud no fue aprobada'), findsOneWidget);
    });

    testWidgets('editar llena el formulario y cancelar vuelve al resumen',
        (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: completeProfile()),
      );

      await _tap(tester, _key('profile-edit'));
      expect(_title(tester), 'Edita tu perfil profesional');
      expect(_key('technician-steps'), findsNothing);
      final years = tester.widget<EditableText>(
        find.descendant(
          of: _key('profile-years-field'),
          matching: find.byType(EditableText),
        ),
      );
      expect(years.controller.text, '8');

      await _tap(tester, _key('profile-cancel'));
      expect(_key('technician-profile-summary'), findsOneWidget);
    });

    testWidgets('editar y guardar actualiza el resumen', (tester) async {
      final repository =
          FakeTechnicianProfileRepository(profile: completeProfile());
      await _pump(tester, repository);

      await _tap(tester, _key('profile-edit'));
      await tester.enterText(_key('profile-years-field'), '12');
      await _tap(tester, _key('profile-save'));

      expect(repository.lastUpdate?.yearsOfExperience, 12);
      expect(find.text('12 años'), findsOneWidget);
    });
  });

  group('carga y sesión', () {
    testWidgets('mientras carga muestra el indicador', (tester) async {
      final repository = _SlowRepository();
      tester.view.physicalSize = const Size(1024, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: TechnicianProfilePage(
            getProfile: GetTechnicianProfile(repository),
            updateProfile: UpdateTechnicianProfile(repository),
          ),
        ),
      );

      expect(_key('technician-profile-loading'), findsOneWidget);
      repository.pending.complete();
      await tester.pumpAndSettle();
      expect(_key('technician-profile-form'), findsOneWidget);
    });

    testWidgets('si no carga permite reintentar', (tester) async {
      final repository = FakeTechnicianProfileRepository(
        profile: emptyProfile,
        fetchFailure: const TechnicianProfileFailure('Sin conexión'),
      );
      await _pump(tester, repository);

      expect(_key('technician-profile-load-error'), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);

      repository.fetchFailure = null;
      await _tap(tester, _key('technician-profile-retry'));
      expect(_key('technician-profile-form'), findsOneWidget);
    });

    testWidgets('avisa una sola vez cuando la sesión vence', (tester) async {
      var expired = 0;
      await _pump(
        tester,
        FakeTechnicianProfileRepository(
          profile: emptyProfile,
          fetchFailure: const TechnicianProfileFailure(
            'Tu sesión venció',
            isSessionExpired: true,
          ),
        ),
        onSessionExpired: () => expired++,
      );

      expect(expired, 1);
    });

    testWidgets('cerrar sesión llama al callback', (tester) async {
      var loggedOut = false;
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: completeProfile()),
        onLogout: () async => loggedOut = true,
      );

      await _tap(tester, _key('technician-profile-logout'));

      expect(loggedOut, isTrue);
    });

    testWidgets('sin callback no muestra "Cerrar sesión"', (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: completeProfile()),
      );

      expect(_key('technician-profile-logout'), findsNothing);
    });
  });

  for (final size in const [Size(320, 900), Size(375, 900)]) {
    testWidgets('en celular de ${size.width.toInt()} px no hay desbordes',
        (tester) async {
      await _pump(
        tester,
        FakeTechnicianProfileRepository(profile: emptyProfile),
        size: size,
        onLogout: () async {},
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _SlowRepository extends FakeTechnicianProfileRepository {
  _SlowRepository() : super(profile: emptyProfile);

  final pending = Completer<void>();

  @override
  Future<TechnicianProfile> fetchProfile() async {
    await pending.future;
    return super.fetchProfile();
  }
}
