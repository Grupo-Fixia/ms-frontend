import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/profile/domain/professional_profile_update.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile.dart';
import 'package:ms_frontend/features/technician/profile/domain/technician_profile_rules.dart';
import 'package:ms_frontend/features/technician/profile/domain/verification_status.dart';

import 'fixtures.dart';

void main() {
  group('TechnicianProfile.isComplete', () {
    test('un técnico recién registrado tiene el perfil incompleto', () {
      expect(emptyProfile.isComplete, isFalse);
    });

    test('con descripción, experiencia y categorías está completo', () {
      expect(completeProfile().isComplete, isTrue);
    });

    test('le falta cualquiera de los tres datos: incompleto', () {
      const base = TechnicianProfile(
        technicianId: 't',
        verificationStatus: VerificationStatus.pending,
        professionalDescription: 'Plomero',
        yearsOfExperience: 3,
        categories: {ServiceCategory.plumbing},
      );
      expect(base.isComplete, isTrue);
      expect(
        const TechnicianProfile(
          technicianId: 't',
          verificationStatus: VerificationStatus.pending,
          professionalDescription: '   ',
          yearsOfExperience: 3,
          categories: {ServiceCategory.plumbing},
        ).isComplete,
        isFalse,
      );
      expect(
        const TechnicianProfile(
          technicianId: 't',
          verificationStatus: VerificationStatus.pending,
          professionalDescription: 'Plomero',
          categories: {ServiceCategory.plumbing},
        ).isComplete,
        isFalse,
      );
      expect(
        const TechnicianProfile(
          technicianId: 't',
          verificationStatus: VerificationStatus.pending,
          professionalDescription: 'Plomero',
          yearsOfExperience: 3,
        ).isComplete,
        isFalse,
      );
    });
  });

  group('VerificationStatus.fromApi', () {
    test('convierte los valores de ms-users', () {
      expect(VerificationStatus.fromApi('PENDING'), VerificationStatus.pending);
      expect(VerificationStatus.fromApi('VALID'), VerificationStatus.valid);
      expect(
        VerificationStatus.fromApi('REJECTED'),
        VerificationStatus.rejected,
      );
      expect(VerificationStatus.fromApi('EXPIRED'), VerificationStatus.expired);
    });

    test('un valor desconocido devuelve null', () {
      expect(VerificationStatus.fromApi('OTRO'), isNull);
      expect(VerificationStatus.fromApi(null), isNull);
    });
  });

  group('TechnicianProfileRules', () {
    test('descripción obligatoria y de máximo 1000 caracteres', () {
      expect(TechnicianProfileRules.description(null), isNotNull);
      expect(TechnicianProfileRules.description('  '), isNotNull);
      expect(TechnicianProfileRules.description('a' * 1000), isNull);
      expect(TechnicianProfileRules.description('a' * 1001), isNotNull);
    });

    test('años de experiencia entre 0 y 80', () {
      expect(TechnicianProfileRules.yearsOfExperience(null), isNotNull);
      expect(TechnicianProfileRules.yearsOfExperience(-1), isNotNull);
      expect(TechnicianProfileRules.yearsOfExperience(0), isNull);
      expect(TechnicianProfileRules.yearsOfExperience(80), isNull);
      expect(TechnicianProfileRules.yearsOfExperience(81), isNotNull);
    });

    test('convierte el texto de los años', () {
      expect(TechnicianProfileRules.parseYears(' 12 '), 12);
      expect(TechnicianProfileRules.parseYears(''), isNull);
      expect(TechnicianProfileRules.parseYears('doce'), isNull);
      expect(TechnicianProfileRules.parseYears(null), isNull);
    });

    test('al menos una categoría', () {
      expect(TechnicianProfileRules.categories({}), isNotNull);
      expect(
        TechnicianProfileRules.categories({ServiceCategory.painting}),
        isNull,
      );
    });
  });

  group('ProfessionalProfileUpdate.validationErrors', () {
    test('sin errores cuando todo es válido', () {
      const update = ProfessionalProfileUpdate(
        professionalDescription: 'Electricista',
        yearsOfExperience: 5,
        categories: {ServiceCategory.electrical},
      );
      expect(update.validationErrors, isEmpty);
    });

    test('devuelve el error de cada campo con el nombre del backend', () {
      const update = ProfessionalProfileUpdate(
        professionalDescription: '',
        yearsOfExperience: null,
        categories: {},
      );
      expect(update.validationErrors.keys, {
        'professionalDescription',
        'yearsOfExperience',
        'categories',
      });
    });
  });
}
