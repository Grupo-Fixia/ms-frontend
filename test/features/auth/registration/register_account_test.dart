import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/registration/application/ports/account_registration_repository.dart';
import 'package:ms_frontend/features/auth/registration/application/register_account.dart';
import 'package:ms_frontend/features/auth/registration/domain/account_registration.dart';
import 'package:ms_frontend/features/auth/registration/domain/registration_exceptions.dart';

import 'fixtures.dart';

class _RecordingRepository implements AccountRegistrationRepository {
  AccountRegistration? saved;

  @override
  Future<void> register(AccountRegistration registration) async {
    saved = registration;
  }
}

void main() {
  test('envía el registro completo al repositorio', () async {
    final repository = _RecordingRepository();

    await RegisterAccount(repository)(validRegistration());

    expect(repository.saved?.email, 'ana@fixia.com');
    expect(repository.saved?.policyVersion, 'v1.0');
  });

  test('si faltan datos no envía nada e indica qué falta (CA-12)', () async {
    final repository = _RecordingRepository();

    await expectLater(
      RegisterAccount(repository)(validRegistration(email: '')),
      throwsA(
        isA<InvalidRegistrationException>()
            .having((e) => e.missingFields, 'missingFields', ['email']),
      ),
    );
    expect(repository.saved, isNull);
  });

  test('sin consentimiento no envía nada (RF-007)', () async {
    final repository = _RecordingRepository();

    await expectLater(
      RegisterAccount(repository)(validRegistration(consentAccepted: false)),
      throwsA(isA<InvalidRegistrationException>()),
    );
    expect(repository.saved, isNull);
  });
}
