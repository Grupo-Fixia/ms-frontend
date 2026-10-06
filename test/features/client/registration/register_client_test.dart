import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/client/registration/application/ports/client_registration_repository.dart';
import 'package:ms_frontend/features/client/registration/application/register_client.dart';
import 'package:ms_frontend/features/client/registration/domain/client_registration.dart';
import 'package:ms_frontend/features/client/registration/domain/client_registration_exceptions.dart';

import 'fixtures.dart';

class _RecordingRepository implements ClientRegistrationRepository {
  ClientRegistration? saved;

  @override
  Future<void> register(ClientRegistration registration) async {
    saved = registration;
  }
}

void main() {
  test('envía el registro completo al repositorio', () async {
    final repository = _RecordingRepository();

    await RegisterClient(repository)(validRegistration());

    expect(repository.saved?.email, 'ana@fixia.com');
    expect(repository.saved?.policyVersion, 'v1.0');
  });

  test('si faltan datos no envía nada e indica qué falta (CA-12)', () async {
    final repository = _RecordingRepository();

    await expectLater(
      RegisterClient(repository)(validRegistration(email: '')),
      throwsA(
        isA<InvalidClientRegistrationException>()
            .having((e) => e.missingFields, 'missingFields', ['email']),
      ),
    );
    expect(repository.saved, isNull);
  });

  test('sin consentimiento no envía nada (RF-007)', () async {
    final repository = _RecordingRepository();

    await expectLater(
      RegisterClient(repository)(validRegistration(consentAccepted: false)),
      throwsA(isA<InvalidClientRegistrationException>()),
    );
    expect(repository.saved, isNull);
  });
}
