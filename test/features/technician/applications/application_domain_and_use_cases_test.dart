import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/applications/application/application_use_cases.dart';
import 'package:ms_frontend/features/technician/applications/application/ports/application_repository.dart';
import 'package:ms_frontend/features/technician/applications/domain/application_exceptions.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';

const _application = ServiceApplication(
  id: 'app-1',
  status: ApplicationStatus.applied,
  serviceRequest: ApplicationRequestSummary(
    id: 'req-1',
    category: ServiceCategory.plumbing,
    city: 'Bogotá',
    zone: 'Chapinero',
  ),
);

class _FakeRepository implements ApplicationRepository {
  String? appliedTo;
  ProposedPrice? price;
  String? requestedId;

  @override
  Future<ServiceApplication> apply(String serviceRequestId,
      {ProposedPrice? proposedPrice}) async {
    appliedTo = serviceRequestId;
    price = proposedPrice;
    return _application;
  }

  @override
  Future<List<ServiceApplication>> listMine() async => const [_application];

  @override
  Future<ServiceApplication> getMine(String id) async {
    requestedId = id;
    return _application;
  }
}

void main() {
  group('dominio', () {
    test('estados de postulación del backend', () {
      expect(ApplicationStatus.fromApi('SELECTED'), ApplicationStatus.selected);
      expect(ApplicationStatus.fromApi('OTRO'), isNull);
      expect(ApplicationStatus.rejected.label, 'No seleccionado');
    });

    test('motivos de no elegibilidad con explicación', () {
      expect(IneligibilityReason.fromApi('ZONE'), IneligibilityReason.zone);
      expect(IneligibilityReason.fromApi('NUEVO'), isNull);
      for (final reason in IneligibilityReason.values) {
        expect(reason.message, isNotEmpty);
      }
    });

    test('la falla indica si es duplicada o de elegibilidad', () {
      const plain = ApplicationFailure('Mensaje');
      const duplicate =
          ApplicationFailure('Ya', existingApplicationId: 'app-1');
      const notEligible =
          ApplicationFailure('No', reasons: [IneligibilityReason.zone]);

      expect(plain.toString(), 'Mensaje');
      expect(plain.isDuplicate || plain.isNotEligible, isFalse);
      expect(duplicate.isDuplicate, isTrue);
      expect(notEligible.isNotEligible, isTrue);
    });
  });

  group('casos de uso', () {
    test('se postula con el id sin espacios', () async {
      final repository = _FakeRepository();

      final application = await ApplyToServiceRequest(repository)(' req-1 ',
          proposedPrice: ProposedPrice.tryParse('150000,50'));

      expect(repository.appliedTo, 'req-1');
      expect(repository.price?.amount, '150000.5');
      expect(application.status, ApplicationStatus.applied);
    });

    test('sin solicitud no envía nada', () async {
      final repository = _FakeRepository();

      await expectLater(
        ApplyToServiceRequest(repository)('  '),
        throwsA(isA<ApplicationFailure>().having(
          (f) => f.fieldErrors.keys,
          'fieldErrors',
          ['serviceRequestId'],
        )),
      );
      expect(repository.appliedTo, isNull);
    });

    test('sin precio no envía una postulación incompleta', () async {
      final repository = _FakeRepository();
      await expectLater(ApplyToServiceRequest(repository)('req-1'),
          throwsA(isA<ApplicationFailure>()));
      expect(repository.appliedTo, isNull);
    });

    test('lista y consulta las postulaciones', () async {
      final repository = _FakeRepository();

      expect(await ListMyApplications(repository)(), hasLength(1));
      await GetMyApplication(repository)('app-9');
      expect(repository.requestedId, 'app-9');
    });
  });
}
