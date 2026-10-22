import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/registration/application/register_account.dart';
import 'package:ms_frontend/features/auth/registration/domain/registration_exceptions.dart';
import 'package:ms_frontend/features/auth/registration/domain/document_type.dart';
import 'package:ms_frontend/features/auth/registration/presentation/registration_controller.dart';

import 'fake_repository.dart';

final _acceptedAt = DateTime(2026, 10, 6, 12, 30);

RegistrationController _controller(
  FakeAccountRegistrationRepository repository,
) {
  return RegistrationController(
    registerAccount: RegisterAccount(repository),
    clock: () => _acceptedAt,
  );
}

Future<void> _register(
  RegistrationController controller, {
  DocumentType? documentType = DocumentType.cc,
}) {
  return controller.register(
    firstName: ' Ana ',
    lastName: ' Pérez ',
    documentType: documentType,
    documentNumber: ' 1020304050 ',
    email: ' ana@fixia.com ',
    phone: ' 3001234567 ',
    password: 'Segura123',
  );
}

void main() {
  test('usa la política v1.0 y empieza sin consentimiento', () {
    final controller = _controller(FakeAccountRegistrationRepository());

    expect(controller.policyVersion, 'v1.0');
    expect(controller.consentAccepted, isFalse);
    expect(controller.consentAcceptedAt, isNull);
    expect(controller.isLocked, isFalse);
  });

  test('aceptar el consentimiento guarda la fecha; quitarlo la borra', () {
    final controller = _controller(FakeAccountRegistrationRepository());

    controller.setConsentAccepted(true);
    expect(controller.consentAcceptedAt, _acceptedAt);

    controller.setConsentAccepted(false);
    expect(controller.consentAcceptedAt, isNull);
  });

  test('envía los datos recortados, con versión y fecha del consentimiento',
      () async {
    final repository = FakeAccountRegistrationRepository();
    final controller = _controller(repository)..setConsentAccepted(true);

    await _register(controller);

    final saved = repository.saved!;
    expect(saved.firstName, 'Ana');
    expect(saved.lastName, 'Pérez');
    expect(saved.documentNumber, '1020304050');
    expect(saved.email, 'ana@fixia.com');
    expect(saved.phone, '3001234567');
    expect(saved.policyVersion, 'v1.0');
    expect(saved.consentAcceptedAt, _acceptedAt);
    expect(controller.isRegistered, isTrue);
    expect(controller.isLocked, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('sin consentimiento no envía e informa qué falta', () async {
    final repository = FakeAccountRegistrationRepository();
    final controller = _controller(repository);

    await _register(controller);

    expect(repository.calls, 0);
    expect(controller.isRegistered, isFalse);
    expect(controller.errorMessage, contains('acepta el tratamiento'));
  });

  test('sin tipo de documento no envía', () async {
    final repository = FakeAccountRegistrationRepository();
    final controller = _controller(repository)..setConsentAccepted(true);

    await _register(controller, documentType: null);

    expect(repository.calls, 0);
    expect(controller.errorMessage, isNotNull);
  });

  test('guarda el mensaje y los errores por campo del backend', () async {
    final repository = FakeAccountRegistrationRepository(
      failure: const RegistrationFailure(
        'Hay datos que debe corregir',
        fieldErrors: {'email': 'El correo electrónico no es válido'},
      ),
    );
    final controller = _controller(repository)..setConsentAccepted(true);

    await _register(controller);

    expect(controller.errorMessage, 'Hay datos que debe corregir');
    expect(controller.fieldError('email'), 'El correo electrónico no es válido');
    expect(controller.isLocked, isFalse);

    controller.clearFieldError('email');
    expect(controller.fieldError('email'), isNull);
    controller.clearFieldError('phone');
  });

  test('marca el conflicto de cuenta existente y se puede descartar',
      () async {
    final repository = FakeAccountRegistrationRepository(
      failure: const RegistrationFailure(
        'Ya existe una cuenta',
        isAccountConflict: true,
      ),
    );
    final controller = _controller(repository)..setConsentAccepted(true);

    await _register(controller);

    expect(controller.isAccountConflict, isTrue);
    expect(controller.errorMessage, 'Ya existe una cuenta');

    controller.dismissError();
    expect(controller.isAccountConflict, isFalse);
    expect(controller.errorMessage, isNull);
    controller.dismissError();
  });

  test('ignora un segundo envío mientras el primero está en curso', () async {
    final pending = Completer<void>();
    final repository = FakeAccountRegistrationRepository(pending: pending);
    final controller = _controller(repository)..setConsentAccepted(true);

    final first = _register(controller);
    expect(controller.isSubmitting, isTrue);
    await _register(controller);
    expect(repository.calls, 1);

    pending.complete();
    await first;
    expect(controller.isSubmitting, isFalse);
  });
}
