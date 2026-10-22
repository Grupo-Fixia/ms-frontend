import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/client/profile/application/client_profile_use_cases.dart';
import 'package:ms_frontend/features/client/profile/application/ports/client_profile_repository.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_exceptions.dart';
import 'package:ms_frontend/features/client/profile/domain/client_profile_update.dart';

const _profile = ClientProfile(
  id: 'usr-1',
  email: 'ana@fixia.com',
  firstName: 'Ana',
  lastName: 'Pérez',
  phone: '3001234567',
);

class _FakeRepository implements ClientProfileRepository {
  ClientProfileUpdate? updated;

  @override
  Future<ClientProfile> fetchProfile() async => _profile;

  @override
  Future<ClientProfile> updateProfile(ClientProfileUpdate update) async {
    updated = update;
    return ClientProfile(
      id: _profile.id,
      email: _profile.email,
      firstName: update.firstName,
      lastName: update.lastName,
      phone: update.phone,
    );
  }
}

void main() {
  test('consulta el perfil', () async {
    final profile = await GetClientProfile(_FakeRepository())();

    expect(profile.fullName, 'Ana Pérez');
  });

  test('actualiza con los textos sin espacios sobrantes', () async {
    final repository = _FakeRepository();

    final saved = await UpdateClientProfile(repository)(
      const ClientProfileUpdate(
        firstName: '  Ana María ',
        lastName: ' Pérez ',
        phone: ' +573001234567 ',
      ),
    );

    expect(repository.updated!.firstName, 'Ana María');
    expect(repository.updated!.lastName, 'Pérez');
    expect(repository.updated!.phone, '+573001234567');
    expect(saved.firstName, 'Ana María');
  });

  test('no envía datos inválidos y marca cada campo', () async {
    final repository = _FakeRepository();

    await expectLater(
      UpdateClientProfile(repository)(
        ClientProfileUpdate(firstName: ' ', lastName: 'a' * 101, phone: '12'),
      ),
      throwsA(isA<ClientProfileFailure>()
          .having((f) => f.message, 'message',
              UpdateClientProfile.invalidDataMessage)
          .having((f) => f.fieldErrors.keys, 'fieldErrors',
              ['firstName', 'lastName', 'phone'])),
    );
    expect(repository.updated, isNull);
  });

  test('el teléfono con espacios internos no es válido (como en ms-users)',
      () async {
    await expectLater(
      UpdateClientProfile(_FakeRepository())(
        const ClientProfileUpdate(
          firstName: 'Ana',
          lastName: 'Pérez',
          phone: '300 123 4567',
        ),
      ),
      throwsA(isA<ClientProfileFailure>()
          .having((f) => f.fieldErrors.keys, 'fieldErrors', ['phone'])),
    );
  });

  test('la falla se muestra con su mensaje', () {
    expect(const ClientProfileFailure('Mensaje').toString(), 'Mensaje');
  });
}
