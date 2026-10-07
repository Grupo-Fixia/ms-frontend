import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/technician_registration/application/register_technician.dart';
import 'package:ms_frontend/features/technician_registration/domain/technician_registration_exceptions.dart';

import 'fake_repository.dart';
import 'fixtures.dart';

void main() {
  test('envía el registro completo al repositorio', () async {
    final repository = FakeTechnicianRegistrationRepository();

    await RegisterTechnician(repository)(validTechnicianRegistration());

    expect(repository.calls, 1);
    expect(repository.saved?.email, 'ana@fixia.com');
    expect(repository.saved?.policyVersion, 'v1.0');
  });

  test('si faltan datos no envía nada e indica qué falta', () async {
    final repository = FakeTechnicianRegistrationRepository();

    await expectLater(
      RegisterTechnician(repository)(
        validTechnicianRegistration(email: ''),
      ),
      throwsA(
        isA<InvalidTechnicianRegistrationException>()
            .having((error) => error.missingFields, 'missingFields', ['email']),
      ),
    );
    expect(repository.calls, 0);
  });

  test('sin consentimiento no envía nada', () async {
    final repository = FakeTechnicianRegistrationRepository();

    await expectLater(
      RegisterTechnician(repository)(
        validTechnicianRegistration(consentAccepted: false),
      ),
      throwsA(isA<InvalidTechnicianRegistrationException>()),
    );
    expect(repository.calls, 0);
  });
}
