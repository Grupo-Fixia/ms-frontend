import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/client/service_requests/application/ports/service_request_repository.dart';
import 'package:ms_frontend/features/client/service_requests/application/service_request_use_cases.dart';
import 'package:ms_frontend/features/client/service_requests/domain/applicant.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';

final _now = DateTime.utc(2026, 10, 19, 15);

ServiceRequest _published(NewServiceRequest request) => ServiceRequest(
      id: 'req-1',
      category: request.category!,
      description: request.description,
      status: ServiceRequestStatus.published,
      approximateLocation: request.approximateLocation,
      expectedAt: request.expectedAt!,
      budget: request.budget,
    );

class _FakeRepository implements ServiceRequestRepository {
  NewServiceRequest? published;
  String? requestedId;
  (String, String)? selection;

  @override
  Future<ServiceRequest> publish(NewServiceRequest request) async {
    published = request;
    return _published(request);
  }

  @override
  Future<List<ServiceRequest>> listMine() async => const [];

  @override
  Future<List<Applicant>> listApplicants(String requestId) async {
    requestedId = requestId;
    return const [
      Applicant(
        id: 'app-1',
        providerId: 'tec-1',
        status: ApplicationStatus.applied,
      ),
    ];
  }

  @override
  Future<ServiceRequest> selectProvider(
    String requestId,
    String applicationId,
  ) async {
    selection = (requestId, applicationId);
    return getMine(requestId);
  }

  @override
  Future<ServiceRequest> getMine(String id) async {
    requestedId = id;
    return _published(NewServiceRequest(
      category: ServiceCategory.painting,
      description: 'x',
      approximateLocation: const ApproximateLocation(city: 'a', zone: 'b'),
      expectedAt: _now,
    ));
  }
}

void main() {
  test('publica con los textos sin espacios sobrantes', () async {
    final repository = _FakeRepository();
    final photos = ['a.jpg'];

    final saved = await PublishServiceRequest(repository, now: () => _now)(
      NewServiceRequest(
        category: ServiceCategory.plumbing,
        description: '  Fuga  ',
        approximateLocation: const ApproximateLocation(
          city: ' Bogotá ',
          zone: ' Chapinero ',
          latitude: 4.65,
          longitude: -74.08,
        ),
        exactLocation: const ExactLocation(address: ' Calle 10 '),
        expectedAt: _now.add(const Duration(days: 1)),
        photoKeys: photos,
        budget: ServiceBudget.tryParse('150000,25'),
      ),
    );

    final sent = repository.published!;
    expect(saved.status, ServiceRequestStatus.published);
    expect(sent.budget!.amount, '150000.25');
    expect(saved.budget!.amount, '150000.25');
    expect(sent.description, 'Fuga');
    expect(sent.approximateLocation.city, 'Bogotá');
    expect(sent.approximateLocation.zone, 'Chapinero');
    expect(sent.approximateLocation.latitude, 4.65);
    expect(sent.exactLocation!.address, 'Calle 10');
    expect(() => sent.photoKeys.add('b.jpg'), throwsUnsupportedError);
  });

  test('sin dirección exacta no la envía', () async {
    final repository = _FakeRepository();

    await PublishServiceRequest(repository, now: () => _now)(
      NewServiceRequest(
        category: ServiceCategory.plumbing,
        description: 'Fuga',
        approximateLocation:
            const ApproximateLocation(city: 'Bogotá', zone: 'Chapinero'),
        expectedAt: _now.add(const Duration(hours: 2)),
        budget: ServiceBudget.tryParse('150000'),
      ),
    );

    expect(repository.published!.exactLocation, isNull);
  });

  test('no envía una solicitud inválida', () async {
    final repository = _FakeRepository();

    await expectLater(
      PublishServiceRequest(repository, now: () => _now)(
        const NewServiceRequest(
          category: null,
          description: '',
          approximateLocation: ApproximateLocation(city: '', zone: ''),
          expectedAt: null,
        ),
      ),
      throwsA(isA<ServiceRequestFailure>()
          .having((f) => f.message, 'message',
              PublishServiceRequest.invalidDataMessage)
          .having((f) => f.fieldErrors, 'fieldErrors', hasLength(6))),
    );
    expect(repository.published, isNull);
  });

  test('por defecto usa la hora actual', () async {
    await expectLater(
      PublishServiceRequest(_FakeRepository())(
        NewServiceRequest(
          category: ServiceCategory.plumbing,
          description: 'Fuga',
          approximateLocation:
              const ApproximateLocation(city: 'Bogotá', zone: 'Chapinero'),
          expectedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ),
      throwsA(isA<ServiceRequestFailure>()),
    );
  });

  test('lista y consulta las solicitudes del cliente', () async {
    final repository = _FakeRepository();

    expect(await ListMyServiceRequests(repository)(), isEmpty);
    await GetMyServiceRequest(repository)('req-9');
    expect(repository.requestedId, 'req-9');
  });

  test('consulta los postulantes de una solicitud', () async {
    final repository = _FakeRepository();

    final applicants = await ListApplicants(repository)('req-1');

    expect(repository.requestedId, 'req-1');
    expect(applicants.single.providerId, 'tec-1');
  });

  test('selecciona al prestador con los ids sin espacios', () async {
    final repository = _FakeRepository();

    await SelectProvider(repository)(' req-1 ', ' app-1 ');

    expect(repository.selection, ('req-1', 'app-1'));
  });

  test('sin postulación elegida no envía nada', () async {
    final repository = _FakeRepository();

    await expectLater(
      SelectProvider(repository)('req-1', ' '),
      throwsA(isA<ServiceRequestFailure>().having(
        (f) => f.fieldErrors.keys,
        'fieldErrors',
        ['applicationId'],
      )),
    );
    expect(repository.selection, isNull);
  });
}
