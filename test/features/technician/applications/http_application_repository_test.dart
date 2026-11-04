import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/constants/service_request_status.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/technician/applications/domain/application_exceptions.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';
import 'package:ms_frontend/features/technician/applications/infrastructure/http_application_repository.dart';

const _endpoint = 'http://localhost/api/services/applications';
final _price = ProposedPrice.tryParse('150000')!;

/// Respuesta como la de ms-services: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpApplicationRepository _repository(MockClientHandler handler) =>
    HttpApplicationRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 'token-1',
        renewSession: () async => false,
      ),
    );

Map<String, Object?> _applicationJson({
  String id = 'app-1',
  String status = 'APPLIED',
  Object? serviceRequest,
}) =>
    {
      'id': id,
      'status': status,
      'providerType': 'INDEPENDENT',
      'technicianId': null,
      'proposedAmount': 150000,
      'currency': 'COP',
      'createdAt': '2026-10-19T15:00:00Z',
      'updatedAt': '2026-10-19T15:00:00Z',
      'serviceRequest': serviceRequest ??
          {
            'id': 'req-1',
            'category': 'PLUMBING',
            'status': 'PUBLISHED',
            'city': 'Bogotá',
            'zone': 'Chapinero',
            'latitude': 4.65,
            'longitude': -74,
            'expectedAt': '2026-10-20T15:00:00Z',
          },
    };

TypeMatcher<ApplicationFailure> _failure(String message) =>
    isA<ApplicationFailure>().having((f) => f.message, 'message', message);

void main() {
  group('contrato GC-423', () {
    test(
        'no pierde centavos en importes grandes ni cambia número por texto JSON',
        () async {
      const amount = '9007199254740993.01';
      late String sent;
      final response = jsonEncode(_applicationJson())
          .replaceFirst('"proposedAmount":150000', '"proposedAmount":$amount');
      final saved = await _repository((request) async {
        sent = request.body;
        return http.Response.bytes(utf8.encode(response), 201);
      }).apply('req-1', proposedPrice: ProposedPrice.tryParse(amount));
      expect(sent, contains('"proposedAmount":$amount'));
      expect(sent, isNot(contains('"proposedAmount":"')));
      expect(saved.proposedPrice?.amount, amount);
    });

    test('un 201 sin precio confirmado no se presenta como éxito', () async {
      await expectLater(
          _repository((_) async => _json(201, {
                ..._applicationJson(),
                'proposedAmount': null,
              })).apply('req-1', proposedPrice: _price),
          throwsA(_failure(HttpApplicationRepository.unconfirmedPriceMessage)));
    });

    test('rechaza respuesta con precio, ejecutor o solicitud diferente',
        () async {
      for (final change in [
        {'proposedAmount': 12},
        {'providerType': 'COMPANY', 'technicianId': 'otro'},
        {
          'serviceRequest': {
            'id': 'otra',
            'category': 'PLUMBING',
            'city': 'Bogotá',
            'zone': 'Suba',
          }
        },
      ]) {
        await expectLater(
            _repository((_) async => _json(201, {
                  ..._applicationJson(),
                  ...change,
                })).apply('req-1', proposedPrice: _price),
            throwsA(
                _failure(HttpApplicationRepository.unconfirmedPriceMessage)));
      }
    });

    test('lecturas conservan precio histórico ausente, sin inventar cero',
        () async {
      final applications = await _repository((_) async => _json(200, [
            {..._applicationJson(), 'proposedAmount': null},
            _applicationJson(id: 'app-2'),
          ])).listMine();
      expect(applications.first.proposedPrice, isNull);
      expect(applications.last.proposedPrice?.amount, '150000');
    });

    test('lectura rechaza importe inválido, tipo incorrecto y otra moneda',
        () async {
      for (final change in [
        {'proposedAmount': -1},
        {'proposedAmount': 0},
        {'proposedAmount': 1.001},
        {'proposedAmount': '150000'},
        {'currency': 'USD'},
        {'providerType': 'COMPANY', 'technicianId': null},
        {'providerType': 'NUEVO'},
      ]) {
        await expectLater(
            _repository((_) async => _json(200, {
                  ..._applicationJson(),
                  ...change,
                })).getMine('app-1'),
            throwsA(
                _failure(HttpApplicationRepository.unconfirmedPriceMessage)));
      }
    });

    test('400 informa error de importe y no reintenta el POST', () async {
      var writes = 0;
      await expectLater(
          _repository((_) async {
            writes++;
            return _json(400, {
              'errors': [
                {'field': 'proposedAmount', 'message': 'Máximo dos decimales'},
              ]
            });
          }).apply('req-1', proposedPrice: _price),
          throwsA(isA<ApplicationFailure>().having((e) => e.fieldErrors,
              'errores', {'proposedAmount': 'Máximo dos decimales'})));
      expect(writes, 1);
    });

    test('409 no inventa postulación exitosa ni intenta cambiar precio',
        () async {
      var writes = 0;
      await expectLater(
          _repository((_) async {
            writes++;
            return _json(409, {});
          }).apply('req-1', proposedPrice: _price),
          throwsA(_failure(HttpApplicationRepository.conflictMessage)));
      expect(writes, 1);
    });
  });
  group('apply', () {
    test('precio ausente no permite enviar una postulación incompleta',
        () async {
      var calls = 0;
      final repository = _repository((_) async {
        calls++;
        return _json(201, _applicationJson());
      });
      await expectLater(repository.apply('req-1'),
          throwsA(_failure(HttpApplicationRepository.invalidDataMessage)));
      expect(calls, 0);
    });

    test('envía la solicitud y devuelve la postulación', () async {
      late http.Request sent;
      final application = await _repository((request) async {
        sent = request;
        return _json(201, _applicationJson());
      }).apply('req-1', proposedPrice: _price);

      expect(sent.method, 'POST');
      expect(sent.url.toString(), _endpoint);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'serviceRequestId': 'req-1',
        'proposedAmount': 150000,
        'currency': 'COP'
      });
      expect(application.proposedPrice?.amount, '150000');
      expect(application.id, 'app-1');
      expect(application.status, ApplicationStatus.applied);
      expect(application.createdAt, DateTime.utc(2026, 10, 19, 15));
      final request = application.serviceRequest;
      expect(request.category, ServiceCategory.plumbing);
      expect(request.status, ServiceRequestStatus.published);
      expect(request.zone, 'Chapinero');
      expect(request.longitude, -74.0);
      expect(request.expectedAt, DateTime.utc(2026, 10, 20, 15));
    });

    test('409 con applicationId: ya se había postulado', () async {
      await expectLater(
        _repository((_) async => _json(409, {
              'title': 'Postulación duplicada',
              'applicationId': 'app-7',
            })).apply('req-1', proposedPrice: _price),
        throwsA(_failure(HttpApplicationRepository.duplicateMessage)
            .having((f) => f.existingApplicationId, 'id', 'app-7')
            .having((f) => f.isDuplicate, 'isDuplicate', isTrue)),
      );
    });

    test('409 sin applicationId: la solicitud ya no recibe postulaciones',
        () async {
      await expectLater(
        _repository((_) async => _json(409, {'title': 'No disponible'}))
            .apply('req-1', proposedPrice: _price),
        throwsA(_failure(HttpApplicationRepository.conflictMessage)
            .having((f) => f.isDuplicate, 'isDuplicate', isFalse)),
      );
    });

    test('422: no es elegible y dice por qué', () async {
      await expectLater(
        _repository((_) async => _json(422, {
              'reasons': ['ZONE', 'AVAILABILITY', 'NUEVO', 3],
            })).apply('req-1', proposedPrice: _price),
        throwsA(_failure(HttpApplicationRepository.notEligibleMessage).having(
          (f) => f.reasons,
          'reasons',
          [IneligibilityReason.zone, IneligibilityReason.availability],
        )),
      );
    });

    test('422 sin motivos conocidos igual informa', () async {
      await expectLater(
        _repository((_) async => _json(422, {}))
            .apply('req-1', proposedPrice: _price),
        throwsA(_failure(HttpApplicationRepository.notEligibleMessage)
            .having((f) => f.reasons, 'reasons', isEmpty)),
      );
    });

    test('503: no se pudo verificar la elegibilidad', () async {
      await expectLater(
        _repository((_) async => _json(503, {}))
            .apply('req-1', proposedPrice: _price),
        throwsA(
          _failure(HttpApplicationRepository.eligibilityUnavailableMessage),
        ),
      );
    });

    test('400 trae los errores por campo', () async {
      await expectLater(
        _repository((_) async => _json(400, {
              'errors': [
                {'field': 'serviceRequestId', 'message': 'Obligatorio'},
                {'field': 'serviceRequestId', 'message': 'Otro'},
                {'field': 'x', 'message': ''},
                'basura',
              ],
            })).apply('x', proposedPrice: _price),
        throwsA(_failure(HttpApplicationRepository.invalidDataMessage).having(
          (f) => f.fieldErrors,
          'fieldErrors',
          {'serviceRequestId': 'Obligatorio'},
        )),
      );
    });

    test('si la respuesta no trae una postulación válida, es un error',
        () async {
      await expectLater(
        _repository((_) async => _json(201, {'id': 'app-1'}))
            .apply('req-1', proposedPrice: _price),
        throwsA(_failure(HttpApplicationRepository.unexpectedErrorMessage)),
      );
    });
  });

  group('listMine', () {
    test('lista y descarta las que no entiende', () async {
      late http.Request sent;
      final applications = await _repository((request) async {
        sent = request;
        return _json(200, [
          _applicationJson(id: 'app-2', status: 'SELECTED'),
          _applicationJson(id: 'app-1'),
          _applicationJson(id: 'app-3', status: 'NUEVO'),
          _applicationJson(id: 'app-4', serviceRequest: 'x'),
          _applicationJson(id: 'app-5', serviceRequest: {
            'id': 'req-5',
            'category': 'GARDENING',
            'city': 'Bogotá',
            'zone': 'Suba',
          }),
          _applicationJson(id: ''),
          'basura',
        ]);
      }).listMine();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), _endpoint);
      expect(applications.map((a) => a.id), ['app-2', 'app-1']);
      expect(applications.first.status, ApplicationStatus.selected);
      expect(() => (applications as List).add(applications.first),
          throwsUnsupportedError);
    });

    test('tolera estado de solicitud desconocido y campos opcionales',
        () async {
      final applications = await _repository((_) async => _json(200, [
            {
              'id': 'app-1',
              'status': 'REJECTED',
              'serviceRequest': {
                'id': 'req-1',
                'category': 'PAINTING',
                'status': 'NUEVO',
                'city': 'Bogotá',
                'zone': 'Usaquén',
                'latitude': null,
                'expectedAt': 7,
              },
            },
          ])).listMine();

      final request = applications.single.serviceRequest;
      expect(request.status, isNull);
      expect(request.latitude, isNull);
      expect(request.expectedAt, isNull);
      expect(applications.single.createdAt, isNull);
    });

    test('respuesta que no es lista o no es JSON es un error', () async {
      for (final response in [
        _json(200, {}),
        http.Response('no-json', 200),
      ]) {
        await expectLater(
          _repository((_) async => response).listMine(),
          throwsA(_failure(HttpApplicationRepository.unexpectedErrorMessage)),
        );
      }
    });
  });

  group('getMine', () {
    test('consulta la postulación por id', () async {
      late http.Request sent;
      final application = await _repository((request) async {
        sent = request;
        return _json(200, _applicationJson(id: 'abc'));
      }).getMine('abc');

      expect(sent.url.toString(), '$_endpoint/abc');
      expect(application.id, 'abc');
    });

    test('404: no existe', () async {
      await expectLater(
        _repository((_) async => _json(404, {})).getMine('abc'),
        throwsA(_failure(HttpApplicationRepository.notFoundMessage)),
      );
    });
  });

  group('errores comunes', () {
    test('403: la sección es solo para técnicos', () async {
      await expectLater(
        _repository((_) async => _json(403, {})).listMine(),
        throwsA(_failure(HttpApplicationRepository.forbiddenMessage)),
      );
    });

    test('500 es un error genérico', () async {
      await expectLater(
        _repository((_) async => http.Response('', 500)).listMine(),
        throwsA(_failure(HttpApplicationRepository.unexpectedErrorMessage)),
      );
    });

    test('si la sesión no se puede renovar, la sesión expiró', () async {
      await expectLater(
        _repository((_) async => http.Response('', 401)).listMine(),
        throwsA(_failure(HttpApplicationRepository.sessionExpiredMessage)
            .having((f) => f.isSessionExpired, 'isSessionExpired', isTrue)),
      );
    });

    test('sin red se pide revisar la conexión', () async {
      await expectLater(
        _repository((_) => throw http.ClientException('sin red'))
            .apply('req-1', proposedPrice: _price),
        throwsA(_failure(HttpApplicationRepository.connectionErrorMessage)),
      );
    });
  });
}
