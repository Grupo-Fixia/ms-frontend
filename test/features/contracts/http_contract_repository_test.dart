import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/contracts/domain/contract_exceptions.dart';
import 'package:ms_frontend/features/contracts/infrastructure/http_contract_repository.dart';

http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpContractRepository _repository(
  MockClientHandler handler, {
  Future<bool> Function()? renew,
}) =>
    HttpContractRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 'token-1',
        renewSession: renew ?? () async => false,
      ),
    );

Map<String, Object?> _contractJson({
  String id = 'c-1',
  Object amount = 150000.5,
  Map<String, Object?>? exact = const {'address': 'Calle 45 # 12-30'},
}) =>
    {
      'id': id,
      'serviceRequestId': 'req-1',
      'quotationId': 'q-1',
      'clientId': 'cli-1',
      'providerId': 'tec-1',
      'amount': amount,
      'currency': 'COP',
      'scope': 'Cambio de tubería',
      'conditions': 'Pago contra entrega',
      'agreedAt': '2026-10-25T15:00:00Z',
      'contractedAt': '2026-10-22T20:00:00Z',
      'serviceRequest': {
        'category': ServiceCategory.plumbing.apiValue,
        'description': 'Fuga en el baño',
        'status': 'CONTRACTED',
        'approximateLocation': {
          'city': 'Bogotá',
          'zone': 'Chapinero',
          'latitude': null,
          'longitude': null,
        },
        if (exact != null) 'exactLocation': exact,
        'expectedAt': '2026-10-25T14:00:00Z',
      },
    };

TypeMatcher<ContractFailure> _failure(String message) =>
    isA<ContractFailure>().having((f) => f.message, 'message', message);

void main() {
  test('el cliente consulta la contratación de su solicitud', () async {
    late http.Request sent;
    final contract = await _repository((request) async {
      sent = request;
      return _json(200, _contractJson());
    }).getForRequest('req-1');

    expect(sent.method, 'GET');
    expect(sent.url.toString(),
        'http://localhost/api/services/requests/req-1/contract');
    expect(sent.headers['Authorization'], 'Bearer token-1');
    expect(contract.id, 'c-1');
    expect(contract.quotationId, 'q-1');
    expect(contract.clientId, 'cli-1');
    expect(contract.providerId, 'tec-1');
    expect(contract.amountInCents, 15000050);
    expect(contract.currency, 'COP');
    expect(contract.scope, 'Cambio de tubería');
    expect(contract.conditions, 'Pago contra entrega');
    expect(contract.agreedAt, DateTime.utc(2026, 10, 25, 15));
    expect(contract.contractedAt, DateTime.utc(2026, 10, 22, 20));
    expect(contract.request.category, ServiceCategory.plumbing);
    expect(contract.request.description, 'Fuga en el baño');
    expect(contract.request.city, 'Bogotá');
    expect(contract.request.zone, 'Chapinero');
    expect(contract.request.exactAddress, 'Calle 45 # 12-30');
    expect(contract.request.expectedAt, DateTime.utc(2026, 10, 25, 14));
  });

  test('sin dirección exacta queda vacía', () async {
    final contract = await _repository(
      (_) async => _json(200, _contractJson(exact: null)),
    ).getForRequest('req-1');

    expect(contract.request.exactAddress, isNull);
  });

  test('el prestador lista sus contrataciones y descarta las incompletas',
      () async {
    late http.Request sent;
    final contracts = await _repository((request) async {
      sent = request;
      return _json(200, [
        _contractJson(),
        {'id': 'roto'},
        _contractJson(id: 'c-2', amount: 80000),
      ]);
    }).listMine();

    expect(sent.url.toString(), 'http://localhost/api/services/contracts');
    expect(contracts.map((c) => c.id), ['c-1', 'c-2']);
    expect(contracts.last.amountInCents, 8000000);
  });

  test('el prestador consulta una contratación', () async {
    late http.Request sent;
    final contract = await _repository((request) async {
      sent = request;
      return _json(200, _contractJson());
    }).getMine('c-1');

    expect(sent.url.toString(), 'http://localhost/api/services/contracts/c-1');
    expect(contract.request.exactAddress, 'Calle 45 # 12-30');
  });

  test('404: la solicitud aún no está contratada', () async {
    await expectLater(
      _repository((_) async => _json(404, {})).getForRequest('req-1'),
      throwsA(_failure(HttpContractRepository.notFoundMessage)
          .having((f) => f.isNotFound, 'isNotFound', isTrue)),
    );
  });

  test('403 y otros errores se traducen a mensajes claros', () async {
    await expectLater(
      _repository((_) async => _json(403, {})).getMine('c-1'),
      throwsA(_failure(HttpContractRepository.forbiddenMessage)),
    );
    await expectLater(
      _repository((_) async => _json(500, {})).getMine('c-1'),
      throwsA(_failure(HttpContractRepository.unexpectedErrorMessage)),
    );
  });

  test('una respuesta que no se entiende es un error', () async {
    await expectLater(
      _repository((_) async => _json(200, {'id': 'c-1'})).getMine('c-1'),
      throwsA(_failure(HttpContractRepository.unexpectedErrorMessage)),
    );
    await expectLater(
      _repository((_) async => http.Response('no-json', 200)).listMine(),
      throwsA(_failure(HttpContractRepository.unexpectedErrorMessage)),
    );
  });

  test('si la sesión no se puede renovar, la sesión expiró', () async {
    await expectLater(
      _repository((_) async => _json(401, {})).listMine(),
      throwsA(_failure(HttpContractRepository.sessionExpiredMessage)
          .having((f) => f.isSessionExpired, 'isSessionExpired', isTrue)),
    );
  });

  test('sin red se pide revisar la conexión', () async {
    await expectLater(
      _repository((_) async => throw http.ClientException('sin red'))
          .getForRequest('req-1'),
      throwsA(_failure(HttpContractRepository.connectionErrorMessage)),
    );
  });
}
