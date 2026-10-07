import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/models/document_type.dart';
import 'package:ms_frontend/features/technician/registration/application/register_technician.dart';
import 'package:ms_frontend/features/technician/registration/domain/technician_registration_exceptions.dart';
import 'package:ms_frontend/features/technician/registration/domain/technician_profession.dart';
import 'package:ms_frontend/features/technician/registration/presentation/technician_registration_controller.dart';

import 'fake_repository.dart';

final _acceptedAt = DateTime(2026, 10, 6, 12, 30);

TechnicianRegistrationController _controller(
  FakeTechnicianRegistrationRepository repository,
) {
  return TechnicianRegistrationController(
    registerTechnician: RegisterTechnician(repository),
    clock: () => _acceptedAt,
  );
}

void main() {
  test('registra la aceptación de la política con fecha', () {
    final controller = _controller(FakeTechnicianRegistrationRepository());

    expect(controller.policyVersion, 'v1.0');
    expect(controller.consentAccepted, isFalse);
    controller.setConsentAccepted(true);

    expect(controller.consentAcceptedAt, _acceptedAt);
    controller.setConsentAccepted(false);
    expect(controller.consentAcceptedAt, isNull);
  });

  test('sin profesión informa el error sin enviar', () async {
    final repository = FakeTechnicianRegistrationRepository();
    final controller = _controller(repository)..setConsentAccepted(true);

    await controller.register(
      firstName: 'Ana',
      lastName: 'Pérez',
      profession: null,
      documentType: DocumentType.cc,
      documentNumber: '1020304050',
      email: 'ana@fixia.com',
      phone: '3001234567',
      password: 'Segura123',
    );

    expect(repository.calls, 0);
    expect(controller.errorMessage, isNotNull);
    expect(controller.isSubmitting, isFalse);
  });

  test('sin tipo de documento informa el error sin enviar', () async {
    final repository = FakeTechnicianRegistrationRepository();
    final controller = _controller(repository)..setConsentAccepted(true);

    await controller.register(
      firstName: 'Ana',
      lastName: 'Pérez',
      profession: TechnicianProfession.electrical,
      documentType: null,
      documentNumber: '1020304050',
      email: 'ana@fixia.com',
      phone: '3001234567',
      password: 'Segura123',
    );

    expect(repository.calls, 0);
    expect(controller.errorMessage, isNotNull);
  });

  test('conserva y limpia errores de campo del repositorio', () async {
    final repository = FakeTechnicianRegistrationRepository(
      failure: const TechnicianRegistrationFailure(
        'Hay datos que debe corregir',
        fieldErrors: {'email': 'El correo no es válido.'},
      ),
    );
    final controller = _controller(repository)..setConsentAccepted(true);

    await controller.register(
      firstName: 'Ana',
      lastName: 'Pérez',
      profession: TechnicianProfession.electrical,
      documentType: DocumentType.cc,
      documentNumber: '1020304050',
      email: 'ana@fixia.com',
      phone: '3001234567',
      password: 'Segura123',
    );

    expect(controller.errorMessage, 'Hay datos que debe corregir');
    expect(controller.fieldError('email'), 'El correo no es válido.');
    controller.clearFieldError('email');
    expect(controller.fieldError('email'), isNull);
  });

  test('evita envíos simultáneos', () async {
    final pending = Completer<void>();
    final repository = FakeTechnicianRegistrationRepository(pending: pending);
    final controller = _controller(repository)..setConsentAccepted(true);
    final first = controller.register(
      firstName: 'Ana',
      lastName: 'Pérez',
      profession: TechnicianProfession.electrical,
      documentType: DocumentType.cc,
      documentNumber: '1020304050',
      email: 'ana@fixia.com',
      phone: '3001234567',
      password: 'Segura123',
    );

    await controller.register(
      firstName: 'Ana',
      lastName: 'Pérez',
      profession: TechnicianProfession.electrical,
      documentType: DocumentType.cc,
      documentNumber: '1020304050',
      email: 'ana@fixia.com',
      phone: '3001234567',
      password: 'Segura123',
    );
    expect(repository.calls, 1);
    pending.complete();
    await first;
  });
}
