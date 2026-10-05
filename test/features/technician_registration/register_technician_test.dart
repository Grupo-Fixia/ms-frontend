import 'package:ms_frontend/features/technician_registration/domain/entities/technician_registration.dart';
import 'package:ms_frontend/features/technician_registration/domain/repositories/technician_registration_repository.dart';
import 'package:ms_frontend/features/technician_registration/domain/usecases/register_technician.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingRepository implements TechnicianRegistrationRepository {
  TechnicianRegistration? savedRegistration;

  @override
  Future<void> register(TechnicianRegistration registration) async {
    savedRegistration = registration;
  }
}

TechnicianRegistration _validRegistration({
  String firstName = 'Ana',
  String password = 'Clave1234',
  bool consentAccepted = true,
  bool provideConsentTimestamp = true,
  DateTime? consentAcceptedAt,
}) {
  return TechnicianRegistration(
    firstName: firstName,
    lastName: 'Pérez',
    documentType: TechnicianDocumentType.cc,
    documentNumber: '1020304050',
    email: 'ana@example.com',
    phone: '+573001112233',
    password: password,
    policyVersion: 'v1.0',
    consentAccepted: consentAccepted,
    consentAcceptedAt: provideConsentTimestamp
        ? consentAcceptedAt ?? DateTime.utc(2026, 10, 5, 12)
        : null,
  );
}

void main() {
  test(
    'rechaza campos obligatorios faltantes sin llamar al repositorio',
    () async {
      final repository = _RecordingRepository();
      final useCase = RegisterTechnician(repository);

      await expectLater(
        useCase(_validRegistration(firstName: '')),
        throwsA(
          isA<InvalidTechnicianRegistrationException>().having(
            (error) => error.missingFields,
            'missingFields',
            contains('firstName'),
          ),
        ),
      );
      expect(repository.savedRegistration, isNull);
    },
  );

  test('rechaza consentimiento ausente o sin fecha de aceptación', () async {
    final repository = _RecordingRepository();
    final useCase = RegisterTechnician(repository);

    await expectLater(
      useCase(_validRegistration(consentAccepted: false)),
      throwsA(isA<InvalidTechnicianRegistrationException>()),
    );
    expect(repository.savedRegistration, isNull);

    await expectLater(
      useCase(_validRegistration(provideConsentTimestamp: false)),
      throwsA(isA<InvalidTechnicianRegistrationException>()),
    );
    expect(repository.savedRegistration, isNull);
  });

  test('registra el rol profesional y pasa los datos al repositorio', () async {
    final repository = _RecordingRepository();
    final useCase = RegisterTechnician(repository);
    final registration = _validRegistration();

    await useCase(registration);

    expect(repository.savedRegistration, same(registration));
    expect(repository.savedRegistration!.role, TechnicianRole.professional);
    expect(repository.savedRegistration!.policyVersion, 'v1.0');
  });
}
