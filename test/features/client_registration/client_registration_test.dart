import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/client_registration/domain/client_registration_exceptions.dart';
import 'package:ms_frontend/features/client_registration/domain/document_type.dart';

import 'fixtures.dart';

void main() {
  test('un registro completo no tiene campos faltantes', () {
    expect(validRegistration().missingRequiredFields, isEmpty);
  });

  test('reporta cada campo obligatorio vacío con el nombre del backend', () {
    final registration = validRegistration(
      firstName: ' ',
      lastName: '',
      documentNumber: '',
      email: '',
      phone: '',
      password: '',
      policyVersion: '',
      consentAccepted: false,
    );

    expect(registration.missingRequiredFields, [
      'firstName',
      'lastName',
      'documentNumber',
      'email',
      'phone',
      'password',
      'policyVersion',
      'consentAccepted',
    ]);
  });

  test('el consentimiento sin fecha no es válido (RF-007)', () {
    expect(
      validRegistration(withoutConsentDate: true).missingRequiredFields,
      ['consentAccepted'],
    );
  });

  test('toString no expone la contraseña ni datos personales', () {
    final text = validRegistration().toString();
    expect(text, isNot(contains('Segura123')));
    expect(text, isNot(contains('ana@fixia.com')));
  });

  test('los tipos de documento usan los valores del backend', () {
    expect(DocumentType.values.map((type) => type.apiValue),
        ['CC', 'CE', 'PASSPORT']);
  });

  test('las excepciones describen el problema', () {
    expect(
      const InvalidClientRegistrationException(['email']).toString(),
      contains('email'),
    );
    expect(const ClientRegistrationFailure('Falló').toString(), 'Falló');
  });
}
