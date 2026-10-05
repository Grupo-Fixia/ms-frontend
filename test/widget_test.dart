import 'dart:convert';

import 'package:ms_frontend/features/technician_registration/domain/entities/technician_registration.dart';
import 'package:ms_frontend/features/technician_registration/domain/repositories/technician_registration_repository.dart';
import 'package:ms_frontend/features/technician_registration/domain/usecases/register_technician.dart';
import 'package:ms_frontend/features/technician_registration/presentation/pages/technician_registration_page.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _TransparentLogoBundle extends CachingAssetBundle {
  static final _transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lqkAAAAASUVORK5CYII=',
  );

  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/brand/fixia-logo.png') {
      return ByteData.sublistView(Uint8List.fromList(_transparentPng));
    }
    return rootBundle.load(key);
  }
}

class _RecordingRepository implements TechnicianRegistrationRepository {
  @override
  Future<void> register(TechnicianRegistration registration) async {}
}

void main() {
  testWidgets('muestra registro profesional y valida campos obligatorios', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        builder: (context, child) => DefaultAssetBundle(
          bundle: _TransparentLogoBundle(),
          child: child!,
        ),
        home: TechnicianRegistrationPage(
          registerTechnician: RegisterTechnician(_RecordingRepository()),
        ),
      ),
    );

    expect(find.text('Técnico profesional (PROFESSIONAL)'), findsOneWidget);
    await tester.ensureVisible(find.text('Crear cuenta de técnico'));
    await tester.tap(find.text('Crear cuenta de técnico'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('El nombre es obligatorio.'));
    expect(find.text('El nombre es obligatorio.'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Debes aceptar el tratamiento de datos.'),
    );
    expect(find.text('Debes aceptar el tratamiento de datos.'), findsOneWidget);
  });

  testWidgets('muestra versión y fecha al aceptar el consentimiento', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        builder: (context, child) => DefaultAssetBundle(
          bundle: _TransparentLogoBundle(),
          child: child!,
        ),
        home: TechnicianRegistrationPage(
          registerTechnician: RegisterTechnician(_RecordingRepository()),
        ),
      ),
    );

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    expect(find.textContaining('v1.0'), findsOneWidget);
    expect(find.byKey(const ValueKey('consent-accepted-at')), findsOneWidget);
  });
}
