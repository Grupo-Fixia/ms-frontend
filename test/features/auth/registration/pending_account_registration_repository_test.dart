import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/auth/registration/domain/registration_exceptions.dart';
import 'package:ms_frontend/features/auth/registration/infrastructure/pending_account_registration_repository.dart';

import 'fixtures.dart';

void main() {
  test('informa que el registro todavía no está disponible', () async {
    const repository = PendingAccountRegistrationRepository();

    await expectLater(
      repository.register(validRegistration()),
      throwsA(
        isA<RegistrationFailure>().having(
          (failure) => failure.message,
          'message',
          PendingAccountRegistrationRepository.unavailableMessage,
        ),
      ),
    );
  });
}
