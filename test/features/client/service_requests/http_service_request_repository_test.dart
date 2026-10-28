import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/infrastructure/http_service_request_repository.dart';

const _endpoint = 'http://localhost/api/services/requests';

/// Respuesta como la de ms-services: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpServiceRequestRepository _repository(MockClientHandler handler) =>
    HttpServiceRequestRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 'token-1',
        renewSession: () async => false,
      ),
    );

Matcher _failure({
  String? message,
  Map<String, String>? fieldErrors,
  bool isSessionExpired = false,
}) {
  var matcher = isA<ServiceRequestFailure>().having(
    (f) => f.isSessionExpired,
    'isSessionExpired',
    isSessionExpired,
  );
  if (message != null) {
    matcher = matcher.having((f) => f.message, 'message', message);
  }
  if (fieldErrors != null) {
    matcher = matcher.having((f) => f.fieldErrors, 'fieldErrors', fieldErrors);
  }
  return matcher;
}

Map<String, Object?> _requestJson({
  String id = 'req-1',
  String status = 'PUBLISHED',
  String category = 'PLUMBING',
  Object? exactLocation,
}) =>
    {
      'budgetAmount': 150000,
      'budgetCurrency': 'COP',
      'id': id,
      'category': category,
      'description': 'Fuga de agua en el baño',
      'status': status,
      'approximateLocation': {
        'city': 'Bogotá',
        'zone': 'Chapinero',
        'latitude': 4.65,
        'longitude': -74,
      },
      if (exactLocation != null) 'exactLocation': exactLocation,
      'expectedAt': '2026-10-20T15:00:00Z',
      'photoKeys': ['a.jpg', 3],
      'publishedAt': '2026-10-19T15:00:00Z',
      'updatedAt': '2026-10-19T15:00:00Z',
    };

void main() {
  group('publish', () {
    test('envía la solicitud y devuelve la publicada', () async {
      late http.Request sent;
      final published = await _repository((request) async {
        sent = request;
        return _json(201, _requestJson());
      }).publish(NewServiceRequest(
        budget: ServiceBudget.tryParse('150000'),
        category: ServiceCategory.plumbing,
        description: 'Fuga de agua en el baño',
        approximateLocation: const ApproximateLocation(
          city: 'Bogotá',
          zone: 'Chapinero',
          latitude: 4.65,
          longitude: -74.08,
        ),
        exactLocation: const ExactLocation(address: 'Calle 10 # 5-20'),
        expectedAt: DateTime.parse('2026-10-20T10:00:00-05:00'),
        photoKeys: const ['a.jpg'],
      ));

      expect(sent.method, 'POST');
      expect(sent.url.toString(), _endpoint);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'category': 'PLUMBING',
        'budgetAmount': 150000,
        'budgetCurrency': 'COP',
        'description': 'Fuga de agua en el baño',
        'approximateLocation': {
          'city': 'Bogotá',
          'zone': 'Chapinero',
          'latitude': 4.65,
          'longitude': -74.08,
        },
        'exactLocation': {'address': 'Calle 10 # 5-20'},
        'expectedAt': '2026-10-20T15:00:00.000Z',
        'photoKeys': ['a.jpg'],
      });
      expect(published.id, 'req-1');
      expect(published.status, ServiceRequestStatus.published);
      expect(published.description, 'Fuga de agua en el baño');
      expect(published.approximateLocation.longitude, -74.0);
      expect(published.photoKeys, ['a.jpg']);
      expect(published.exactLocation, isNull);
      expect(published.expectedAt, DateTime.utc(2026, 10, 20, 15));
    });

    test('sin datos opcionales no los envía', () async {
      late http.Request sent;
      await _repository((request) async {
        sent = request;
        return _json(201, _requestJson());
      }).publish(NewServiceRequest(
        budget: ServiceBudget.tryParse('150000'),
        category: ServiceCategory.painting,
        description: 'Pintar',
        approximateLocation:
            const ApproximateLocation(city: 'Bogotá', zone: 'Suba'),
        expectedAt: DateTime.utc(2026, 10, 21),
      ));

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body.containsKey('exactLocation'), isFalse);
      expect(body.containsKey('photoKeys'), isFalse);
      expect(body['approximateLocation'], {'city': 'Bogotá', 'zone': 'Suba'});
    });

    test('400 trae los errores con el nombre de campo del backend', () async {
      await expectLater(
        _repository((_) async => _json(400, {
              'detail': 'Hay datos que debe corregir',
              'errors': [
                {'field': 'approximateLocation.city', 'message': 'Obligatoria'},
                {'field': 'photoKeys[2]', 'message': 'No permitida'},
                {'field': 'photoKeys[3]', 'message': 'Otra'},
                {'field': 'x', 'message': ' '},
                'basura',
              ],
            })).publish(NewServiceRequest(
          budget: ServiceBudget.tryParse('150000'),
          category: null,
          description: '',
          approximateLocation: const ApproximateLocation(city: '', zone: ''),
          expectedAt: null,
        )),
        throwsA(_failure(
          message: HttpServiceRequestRepository.invalidDataMessage,
          fieldErrors: {
            'approximateLocation.city': 'Obligatoria',
            'photoKeys': 'No permitida',
          },
        )),
      );
    });

    test('400 por regla de negocio muestra el detail', () async {
      await expectLater(
        _repository((_) async => _json(400, {'detail': 'Regla del backend'}))
            .publish(NewServiceRequest(
          budget: ServiceBudget.tryParse('150000'),
          category: ServiceCategory.plumbing,
          description: 'x',
          approximateLocation: const ApproximateLocation(city: 'a', zone: 'b'),
          expectedAt: null,
        )),
        throwsA(_failure(message: 'Regla del backend', fieldErrors: {})),
      );
    });

    test('si la respuesta no trae una solicitud válida, es un error', () async {
      await expectLater(
        _repository((_) async => _json(201, {'id': 'req-1'}))
            .publish(NewServiceRequest(
          budget: ServiceBudget.tryParse('150000'),
          category: ServiceCategory.plumbing,
          description: 'x',
          approximateLocation: const ApproximateLocation(city: 'a', zone: 'b'),
          expectedAt: null,
        )),
        throwsA(_failure(
          message: HttpServiceRequestRepository.unexpectedErrorMessage,
        )),
      );
    });
  });

  group('listMine', () {
    test('lista las solicitudes y descarta las que no entiende', () async {
      late http.Request sent;
      final requests = await _repository((request) async {
        sent = request;
        return _json(200, [
          _requestJson(
            id: 'req-2',
            status: 'CONTRACTED',
            exactLocation: {'address': 'Calle 10', 'latitude': 4.6533},
          ),
          _requestJson(id: 'req-1'),
          _requestJson(id: 'req-3', status: 'NUEVO_ESTADO'),
          _requestJson(id: 'req-4', category: 'GARDENING'),
          {
            ..._requestJson(id: 'req-5'),
            'approximateLocation': {'city': 'Bogotá'},
          },
          {..._requestJson(id: 'req-6'), 'approximateLocation': 'x'},
          {..._requestJson(id: 'req-7'), 'expectedAt': 'no-es-fecha'},
          {..._requestJson(id: ''), 'description': 7},
          'basura',
        ]);
      }).listMine();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), _endpoint);
      expect(requests.map((r) => r.id), ['req-2', 'req-1']);
      expect(requests.first.status, ServiceRequestStatus.contracted);
      expect(requests.first.exactLocation!.address, 'Calle 10');
      expect(requests.first.exactLocation!.latitude, 4.6533);
      expect(requests.first.exactLocation!.longitude, isNull);
      expect(
          () => (requests as List).add(requests.first), throwsUnsupportedError);
    });

    test('lee el prestador seleccionado y tolera campos raros', () async {
      final requests = await _repository((_) async => _json(200, [
            {
              ..._requestJson(status: 'PROVIDER_SELECTED'),
              'selectedProviderId': 'tec-1',
              'description': null,
              'photoKeys': 'x',
              'exactLocation': {'address': 3},
              'publishedAt': 5,
            },
          ])).listMine();

      final request = requests.single;
      expect(request.selectedProviderId, 'tec-1');
      expect(request.description, '');
      expect(request.photoKeys, isEmpty);
      expect(request.exactLocation, isNull);
      expect(request.publishedAt, isNull);
    });

    test('si la respuesta no es una lista, es un error', () async {
      await expectLater(
        _repository((_) async => _json(200, {})).listMine(),
        throwsA(_failure(
          message: HttpServiceRequestRepository.unexpectedErrorMessage,
        )),
      );
      await expectLater(
        _repository((_) async => http.Response('no-json', 200)).listMine(),
        throwsA(_failure(
          message: HttpServiceRequestRepository.unexpectedErrorMessage,
        )),
      );
    });
  });

  group('getMine', () {
    test('consulta la solicitud por id', () async {
      late http.Request sent;
      final request = await _repository((r) async {
        sent = r;
        return _json(200, _requestJson(id: 'abc'));
      }).getMine('abc');

      expect(sent.url.toString(), '$_endpoint/abc');
      expect(request.id, 'abc');
    });

    test('404 es "no encontramos esa solicitud"', () async {
      await expectLater(
        _repository((_) async => _json(404, {})).getMine('abc'),
        throwsA(_failure(
          message: HttpServiceRequestRepository.notFoundMessage,
        )),
      );
    });
  });

  group('errores comunes', () {
    test('403: la sección es solo para clientes', () async {
      await expectLater(
        _repository((_) async => _json(403, {})).listMine(),
        throwsA(_failure(
          message: HttpServiceRequestRepository.forbiddenMessage,
        )),
      );
    });

    test('500 o un 200 inesperado al publicar es un error genérico', () async {
      await expectLater(
        _repository((_) async => http.Response('', 500)).listMine(),
        throwsA(_failure(
          message: HttpServiceRequestRepository.unexpectedErrorMessage,
        )),
      );
      await expectLater(
        _repository((_) async => _json(200, _requestJson())).publish(
          NewServiceRequest(
            budget: ServiceBudget.tryParse('150000'),
            category: ServiceCategory.plumbing,
            description: 'x',
            approximateLocation:
                const ApproximateLocation(city: 'a', zone: 'b'),
            expectedAt: null,
          ),
        ),
        throwsA(_failure(
          message: HttpServiceRequestRepository.unexpectedErrorMessage,
        )),
      );
    });

    test('si la sesión no se puede renovar, la sesión expiró', () async {
      await expectLater(
        _repository((_) async => http.Response('', 401)).listMine(),
        throwsA(_failure(
          message: HttpServiceRequestRepository.sessionExpiredMessage,
          isSessionExpired: true,
        )),
      );
    });

    test('sin red se pide revisar la conexión', () async {
      await expectLater(
        _repository((_) => throw http.ClientException('sin red')).listMine(),
        throwsA(_failure(
          message: HttpServiceRequestRepository.connectionErrorMessage,
        )),
      );
    });
  });

  test(
      'si ms-services rechaza el token recién renovado, es un error y no una '
      'sesión vencida', () async {
    var token = 'token-1';
    final repository = HttpServiceRequestRepository(
      client: MockClient((_) async => _json(401, {})),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => token,
        renewSession: () async {
          token = 'token-2';
          return true;
        },
      ),
    );

    await expectLater(
      repository.listMine(),
      throwsA(isA<ServiceRequestFailure>()
          .having((f) => f.isSessionExpired, 'isSessionExpired', isFalse)),
    );
  });
}
