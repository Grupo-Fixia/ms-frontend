import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/client/service_requests/application/ports/service_request_repository.dart';
import 'package:ms_frontend/features/client/service_requests/application/service_request_use_cases.dart';
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
    );

class _FakeRepository implements ServiceRequestRepository {
  NewServiceRequest? published;
  String? requestedId;

  @override
  Future<ServiceRequest> publish(NewServiceRequest request) async {
    published = request;
    return _published(request);
  }

  @override
  Future<List<ServiceRequest>> listMine() async => const [];

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
      ),
    );

    final sent = repository.published!;
    expect(saved.status, ServiceRequestStatus.published);
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
          .having((f) => f.fieldErrors, 'fieldErrors', hasLength(5))),
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
}
