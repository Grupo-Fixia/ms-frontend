import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/technician/applications/domain/application_exceptions.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';
import 'package:ms_frontend/features/company/applications/application/company_repositories.dart';
import 'package:ms_frontend/features/company/applications/domain/company_application_failure.dart';
import 'package:ms_frontend/features/company/applications/infrastructure/http_company_application_repository.dart';

http.Response json(int status, Object? body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
AuthorizedHttp auth() => AuthorizedHttp(
    accessToken: () => 'test-company', renewSession: () async => false);
Map<String, Object?> application(
        {String id = 'a1',
        String executor = 'user-1',
        Object? price = 180000.25}) =>
    {
      'id': id,
      'providerType': 'COMPANY',
      'technicianId': executor,
      'status': 'APPLIED',
      'proposedAmount': price,
      'currency': 'COP',
      'createdAt': '2026-10-29T15:00:00Z',
      'serviceRequest': {
        'id': 'r1',
        'category': 'PLUMBING',
        'city': 'Bogotá',
        'zone': 'Chapinero',
        'status': 'PUBLISHED'
      }
    };
HttpCompanyApplicationRepository applications(MockClientHandler handler) =>
    HttpCompanyApplicationRepository(
        client: MockClient(handler),
        baseUrl: Uri.parse('http://localhost'),
        authorizedHttp: auth());

void main() {
  test(
      'POST empresarial reutiliza importe numérico y confirma con GET autorizado',
      () async {
    final methods = <String>[];
    final saved = await applications((req) async {
      methods.add(req.method);
      expect(req.headers['Authorization'], 'Bearer test-company');
      if (req.method == 'POST') {
        expect(req.url.path, '/api/services/applications');
        expect(jsonDecode(req.body), {
          'serviceRequestId': 'r1',
          'technicianId': 'user-1',
          'proposedAmount': 180000.25,
          'currency': 'COP'
        });
        return json(201, application());
      }
      expect(req.url.path, '/api/services/applications/a1');
      return json(200, application());
    }).applyCompany('r1',
        technicianUserId: 'user-1',
        price: ProposedPrice.tryParse('180000,25')!);
    expect(methods, ['POST', 'GET']);
    expect(saved.technicianId, 'user-1');
    expect(saved.proposedPrice!.amount, '180000.25');
  });
  test('valida precio real, sin límite artificial ni alteración de inválidos',
      () async {
    for (final input in ['', '0', '-1', '1.001', '10000000000']) {
      expect(validateCompanyPrice(input), isNotNull);
    }
    expect(validateCompanyPrice('9999999999.99'), isNull);
    var calls = 0;
    await expectLater(
        applications((_) async {
          calls++;
          return json(201, application());
        }).applyCompany('r1',
            technicianUserId: 'user-1',
            price: ProposedPrice.tryParse('10000000000')!),
        throwsA(isA<ApplicationFailure>()));
    expect(calls, 0);
  });
  test('400 conserva errores por campo', () async {
    await expectLater(
        applications((_) async => json(400, {
                  'errors': [
                    {'field': 'technicianId', 'message': 'Obligatorio'}
                  ]
                }))
            .applyCompany('r1',
                technicianUserId: 'user-1',
                price: ProposedPrice.tryParse('180000.25')!),
        throwsA(isA<ApplicationFailure>().having(
            (e) => e.fieldErrors, 'campos', {'technicianId': 'Obligatorio'})));
  });
  for (final status in [403, 404, 409, 422, 503]) {
    test('POST $status no reintenta ni genera confirmación', () async {
      var writes = 0;
      await expectLater(
          applications((_) async {
            writes++;
            return json(status, {
              'reasons': ['TECHNICIAN_NOT_ASSOCIATED']
            });
          }).applyCompany('r1',
              technicianUserId: 'user-1',
              price: ProposedPrice.tryParse('180000.25')!),
          throwsA(isA<ApplicationFailure>()));
      expect(writes, 1);
    });
  }
  test('422 distingue asociación y elegibilidad sin asumir verificación previa',
      () async {
    for (final reason in [
      'TECHNICIAN_NOT_ASSOCIATED',
      'CATEGORY',
      'ZONE',
      'AVAILABILITY',
      'VERIFICATION',
      'NUEVO'
    ]) {
      await expectLater(
          applications((_) async => json(422, {
                    'reasons': [reason]
                  }))
              .applyCompany('r1',
                  technicianUserId: 'user-1',
                  price: ProposedPrice.tryParse('180000.25')!),
          throwsA(isA<ApplicationFailure>()
              .having((e) => e.message, 'mensaje', isNotEmpty)));
    }
  });
  test('201 inconsistente o GET fallido no se confirma', () async {
    for (final body in [
      {...application(), 'technicianId': 'otro'},
      {...application(), 'proposedAmount': null},
      {...application(), 'providerType': 'INDEPENDENT'},
      {...application(), 'currency': 'USD'},
      {...application(), 'id': ''}
    ]) {
      await expectLater(
          applications((_) async => json(201, body)).applyCompany('r1',
              technicianUserId: 'user-1',
              price: ProposedPrice.tryParse('180000.25')!),
          throwsA(isA<CompanySubmissionUnconfirmed>()));
    }
    await expectLater(
        applications((req) async =>
                req.method == 'POST' ? json(201, application()) : json(503, {}))
            .applyCompany('r1',
                technicianUserId: 'user-1',
                price: ProposedPrice.tryParse('180000.25')!),
        throwsA(isA<CompanySubmissionUnconfirmed>()));
  });
  test('red tras enviar exige consultar y no reintenta', () async {
    var calls = 0;
    await expectLater(
        applications((_) {
          calls++;
          throw http.ClientException('offline');
        }).applyCompany('r1',
            technicianUserId: 'user-1',
            price: ProposedPrice.tryParse('180000.25')!),
        throwsA(isA<CompanySubmissionUnconfirmed>()));
    expect(calls, 1);
  });
  test(
      'GET lista y detalle de empresa usan lectura existente sin perder precio',
      () async {
    final repo = applications((req) async => json(
        200, req.url.path.endsWith('a1') ? application() : [application()]));
    expect((await repo.listMine()).single.providerType,
        ApplicationProviderType.company);
    expect((await repo.getMine('a1')).technicianId, 'user-1');
    await expectLater(
        applications((_) async => json(200, application(id: 'otro')))
            .getMine('a1'),
        throwsA(isA<ApplicationFailure>()));
    await expectLater(applications((_) async => json(503, {})).listMine(),
        throwsA(isA<ApplicationFailure>()));
  });
}
