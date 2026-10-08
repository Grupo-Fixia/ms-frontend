import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/profile/application/get_technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/application/update_technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/domain/professional_profile_update.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile_exceptions.dart';
import 'package:ms_frontend/features/technician/profile/domain/verification_status.dart';
import 'package:ms_frontend/features/technician/profile/infrastructure/in_memory_technician_profile_repository.dart';

import 'fake_repository.dart';
import 'fixtures.dart';

void main() {
  test('GetTechnicianProfile consulta el perfil', () async {
    final repository = FakeTechnicianProfileRepository(profile: emptyProfile);

    final profile = await GetTechnicianProfile(repository)();

    expect(profile, same(emptyProfile));
    expect(repository.fetchCalls, 1);
  });

  test('UpdateTechnicianProfile guarda un perfil válido', () async {
    final repository = FakeTechnicianProfileRepository(profile: emptyProfile);
    const update = ProfessionalProfileUpdate(
      professionalDescription: 'Cerrajero 24 horas',
      yearsOfExperience: 10,
      categories: {ServiceCategory.locksmithing},
    );

    final saved = await UpdateTechnicianProfile(repository)(update);

    expect(repository.updateCalls, 1);
    expect(saved.isComplete, isTrue);
    expect(saved.categories, {ServiceCategory.locksmithing});
  });

  test('UpdateTechnicianProfile no envía un perfil inválido', () async {
    final repository = FakeTechnicianProfileRepository(profile: emptyProfile);
    const update = ProfessionalProfileUpdate(
      professionalDescription: '',
      yearsOfExperience: 99,
      categories: {},
    );

    await expectLater(
      UpdateTechnicianProfile(repository)(update),
      throwsA(
        isA<TechnicianProfileFailure>().having(
          (f) => f.fieldErrors.keys,
          'campos',
          containsAll(
            ['professionalDescription', 'yearsOfExperience', 'categories'],
          ),
        ),
      ),
    );
    expect(repository.updateCalls, 0);
  });

  group('InMemoryTechnicianProfileRepository (temporal hasta GC-264)', () {
    test('arranca vacío y pendiente de verificación', () async {
      final repository = InMemoryTechnicianProfileRepository();

      final profile = await repository.fetchProfile();

      expect(profile.isComplete, isFalse);
      expect(profile.verificationStatus, VerificationStatus.pending);
    });

    test('guarda lo que se actualiza', () async {
      final now = DateTime(2026, 10, 8, 12);
      final repository = InMemoryTechnicianProfileRepository(clock: () => now);

      await repository.updateProfile(
        const ProfessionalProfileUpdate(
          professionalDescription: 'Pintor',
          yearsOfExperience: 4,
          categories: {ServiceCategory.painting},
        ),
      );
      final profile = await repository.fetchProfile();

      expect(profile.isComplete, isTrue);
      expect(profile.yearsOfExperience, 4);
      expect(profile.updatedAt, now);
      expect(profile.verificationStatus, VerificationStatus.pending);
    });
  });
}
