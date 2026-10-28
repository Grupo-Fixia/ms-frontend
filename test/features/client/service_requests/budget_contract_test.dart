import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/http_service_request_repository.dart';
import 'package:ms_frontend/features/technician/opportunities/infrastructure/http_opportunity_repository.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity_exceptions.dart';

Map<String, Object?> data(Object? amount, {Object? currency = 'COP'}) => {
      'id': 'request-1',
      'category': 'PLUMBING',
      'description': 'Fuga',
      'status': 'PUBLISHED',
      'expectedAt': '2027-01-01T15:00:00Z',
      'approximateLocation': {'city': 'Bogotá', 'zone': 'Chapinero'},
      'city': 'Bogotá',
      'zone': 'Chapinero',
      'budgetAmount': amount,
      'budgetCurrency': currency,
    };
http.Response response(int status, Object? body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
AuthorizedHttp auth() => AuthorizedHttp(
    accessToken: () => 'test-client-token', renewSession: () async => false);
HttpServiceRequestRepository repo(MockClientHandler handler) =>
    HttpServiceRequestRepository(
        client: MockClient(handler),
        baseUrl: Uri.parse('http://localhost'),
        authorizedHttp: auth());
NewServiceRequest draft(String input) => NewServiceRequest(
      category: ServiceCategory.plumbing,
      description: 'Fuga',
      approximateLocation:
          const ApproximateLocation(city: 'Bogotá', zone: 'Chapinero'),
      expectedAt: DateTime.utc(2027),
      budget: ServiceBudget.tryParse(input),
    );

void main() {
  for (final input in ['200000', '0.01', '9999999999.99', '150000,25']) {
    test('envía y recupera presupuesto exacto $input', () async {
      final budget = ServiceBudget.tryParse(input)!;
      final saved = await repo((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['budgetAmount'], isA<num>());
        expect(body['budgetAmount'].toString(), budget.jsonAmount.toString());
        expect(body['budgetCurrency'], 'COP');
        expect(body.keys, isNot(contains('role')));
        expect(body.keys, isNot(contains('clientId')));
        expect(request.headers['Authorization'], 'Bearer test-client-token');
        expect(request.body, contains('"budgetAmount":${budget.amount}'));
        return response(201, data(body['budgetAmount']));
      }).publish(draft(input));
      expect(saved.budget!.amount, budget.amount);
    });
  }
  for (final input in [
    '',
    '0',
    '-1',
    '1.001',
    '1.000',
    '10000000000',
    '9999999999.999'
  ]) {
    test('no envía otro valor al recibir entrada inválida $input', () async {
      var calls = 0;
      await expectLater(
          repo((_) async {
            calls++;
            return response(201, data(1));
          }).publish(draft(input)),
          throwsA(isA<ServiceRequestFailure>()));
      expect(calls, 0);
    });
  }
  test('GET lista y detalle conservan valor y ausencia histórica', () async {
    for (final amount in [null, 200000.25]) {
      final repository = repo((request) async => response(
          200,
          request.url.path.endsWith('request-1')
              ? data(amount, currency: amount == null ? null : 'COP')
              : [data(amount, currency: amount == null ? null : 'COP')]));
      expect((await repository.listMine()).single.budget?.amount,
          amount?.toString());
      expect((await repository.getMine('request-1')).budget?.amount,
          amount?.toString());
    }
  });
  test('oportunidades leen presupuesto y null', () async {
    final repository = HttpOpportunityRepository(
        client: MockClient((_) async => response(200, {
              'items': [
                data(200000.25),
                {...data(null, currency: null), 'id': 'old'}
              ],
              'nextCursor': null
            })),
        baseUrl: Uri.parse('http://localhost'),
        authorizedHttp: auth());
    final page = await repository.fetchPage(limit: 20);
    expect(page.items.first.budget!.amount, '200000.25');
    expect(page.items.last.budget, isNull);
  });
  test('400 conserva nombres de campo', () async {
    await expectLater(
        repo((_) async => response(400, {
              'errors': [
                {'field': 'budgetAmount', 'message': 'Importe inválido'},
                {'field': 'budgetCurrency', 'message': 'Solo COP'},
              ]
            })).publish(draft('200000')),
        throwsA(isA<ServiceRequestFailure>().having(
            (e) => e.fieldErrors, 'errores', {
          'budgetAmount': 'Importe inválido',
          'budgetCurrency': 'Solo COP'
        })));
  });
  test('red y consultas fallidas no se confirman', () async {
    final repository = repo((_) => throw http.ClientException('offline'));
    await expectLater(repository.publish(draft('200000')),
        throwsA(isA<ServiceRequestFailure>()));
    await expectLater(
        repository.listMine(), throwsA(isA<ServiceRequestFailure>()));
    await expectLater(
        repository.getMine('request-1'), throwsA(isA<ServiceRequestFailure>()));
    await expectLater(repo((_) async => response(503, {})).getMine('request-1'),
        throwsA(isA<ServiceRequestFailure>()));
  });
  test('201 sin confirmar importe no es éxito', () async {
    for (final amount in [null, 100000]) {
      await expectLater(
          repo((_) async => response(
                  201, data(amount, currency: amount == null ? null : 'COP')))
              .publish(draft('200000')),
          throwsA(isA<ServiceRequestFailure>()));
    }
  });
  test('consultas con presupuestos inválidos fallan en vez de inventarlos',
      () async {
    for (final payload in [
      data(1.001),
      data(0),
      data(10000000000),
      data('200000'),
      data(1, currency: 'USD'),
      data(null)
    ]) {
      await expectLater(
          repo((_) async => response(200, payload)).getMine('request-1'),
          throwsA(isA<ServiceRequestFailure>()));
      final opportunities = HttpOpportunityRepository(
          client: MockClient((_) async => response(200, {
                'items': [payload]
              })),
          baseUrl: Uri.parse('http://localhost'),
          authorizedHttp: auth());
      await expectLater(opportunities.fetchPage(limit: 20),
          throwsA(isA<OpportunityFailure>()));
    }
  });
}
