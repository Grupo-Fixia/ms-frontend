import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_rules.dart';

final _now = DateTime.utc(2026, 10, 19, 15);

NewServiceRequest _request({
  ServiceCategory? category = ServiceCategory.plumbing,
  String description = 'Fuga de agua en el baño',
  ApproximateLocation approximate =
      const ApproximateLocation(city: 'Bogotá', zone: 'Chapinero'),
  ExactLocation? exact,
  DateTime? expectedAt,
  bool noExpectedAt = false,
  List<String> photoKeys = const [],
  bool noBudget = false,
}) =>
    NewServiceRequest(
      category: category,
      description: description,
      approximateLocation: approximate,
      exactLocation: exact,
      expectedAt:
          noExpectedAt ? null : expectedAt ?? _now.add(const Duration(days: 1)),
      photoKeys: photoKeys,
      budget: noBudget ? null : ServiceBudget.tryParse('150000'),
    );

Map<String, String> _validate(NewServiceRequest request) =>
    ServiceRequestRules.validate(request, now: _now);

void main() {
  test('nuevas publicaciones requieren presupuesto; no inventa uno', () {
    expect(_validate(_request(noBudget: true))['budgetAmount'], isNotNull);
  });

  test('una solicitud completa es válida', () {
    expect(
      _validate(_request(
        approximate: const ApproximateLocation(
          city: 'Bogotá',
          zone: 'Chapinero',
          latitude: 4.65,
          longitude: -74.08,
        ),
        exact: const ExactLocation(
          address: 'Calle 10 # 5-20',
          latitude: 4.6533,
          longitude: -74.0836,
        ),
        photoKeys: ['fotos/req-1/a.jpg'],
      )),
      isEmpty,
    );
  });

  test('categoría, descripción, ciudad, zona y momento son obligatorios', () {
    final errors = _validate(_request(
      category: null,
      description: '  ',
      approximate: const ApproximateLocation(city: '', zone: ' '),
      noExpectedAt: true,
    ));

    expect(errors.keys, {
      'category',
      'description',
      'approximateLocation.city',
      'approximateLocation.zone',
      'expectedAt',
    });
  });

  test('respeta las longitudes máximas del backend', () {
    final errors = _validate(_request(
      description: 'a' * 2001,
      approximate: ApproximateLocation(city: 'c' * 101, zone: 'z' * 101),
      exact: ExactLocation(address: 'd' * 256),
    ));

    expect(errors['description'], contains('2000'));
    expect(errors['approximateLocation.city'], contains('100'));
    expect(errors['approximateLocation.zone'], contains('100'));
    expect(errors['exactLocation.address'], contains('255'));
  });

  test('la dirección exacta, si se envía, no puede estar vacía', () {
    expect(
      _validate(_request(exact: const ExactLocation(address: ' '))),
      contains('exactLocation.address'),
    );
  });

  test('las coordenadas van juntas y dentro de rango', () {
    expect(
      _validate(_request(
        approximate: const ApproximateLocation(
          city: 'Bogotá',
          zone: 'Chapinero',
          latitude: 4.6,
        ),
        exact: const ExactLocation(address: 'Calle 1', longitude: -74),
      )).keys,
      containsAll([
        'approximateLocation.coordinatesComplete',
        'exactLocation.coordinatesComplete',
      ]),
    );
    expect(
      _validate(_request(
        approximate: const ApproximateLocation(
          city: 'Bogotá',
          zone: 'Chapinero',
          latitude: 91,
          longitude: double.nan,
        ),
      )).keys,
      containsAll([
        'approximateLocation.latitude',
        'approximateLocation.longitude',
      ]),
    );
  });

  test('el momento esperado debe ser posterior a ahora', () {
    expect(_validate(_request(expectedAt: _now)), contains('expectedAt'));
    expect(
      _validate(_request(expectedAt: _now.subtract(const Duration(hours: 1)))),
      contains('expectedAt'),
    );
  });

  test('máximo 5 fotos y con nombres permitidos', () {
    expect(
      _validate(_request(photoKeys: List.filled(6, 'a.jpg')))['photoKeys'],
      contains('5'),
    );
    for (final key in [
      '../secreto',
      '/raiz.jpg',
      'con espacio.jpg',
      'a' * 256
    ]) {
      expect(_validate(_request(photoKeys: [key])), contains('photoKeys'),
          reason: key);
    }
  });

  test('estados del backend', () {
    expect(ServiceRequestStatus.fromApi('PROVIDER_SELECTED'),
        ServiceRequestStatus.providerSelected);
    expect(ServiceRequestStatus.fromApi('OTRO'), isNull);
    expect(ServiceRequestStatus.contracted.label, 'Contratada');
  });

  test('la falla se muestra con su mensaje', () {
    expect(const ServiceRequestFailure('Mensaje').toString(), 'Mensaje');
  });
}
