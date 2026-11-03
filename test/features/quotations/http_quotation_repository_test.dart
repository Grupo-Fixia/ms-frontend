import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/quotations/domain/quotation.dart';
import 'package:ms_frontend/features/quotations/domain/quotation_exceptions.dart';
import 'package:ms_frontend/features/quotations/infrastructure/http_quotation_repository.dart';

/// Respuesta como la de ms-services: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpQuotationRepository _repository(MockClientHandler handler) =>
    HttpQuotationRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => 'token-1',
        renewSession: () async => false,
      ),
    );

TypeMatcher<QuotationFailure> _failure(String message) =>
    isA<QuotationFailure>().having((f) => f.message, 'message', message);

Map<String, Object?> _quotationJson({
  String id = 'q-1',
  String status = 'SENT',
  Object amount = 150000.5,
  Object? statusName = 'Enviada',
  bool expired = false,
}) =>
    {
      'id': id,
      'serviceRequestId': 'req-1',
      'providerId': 'tec-1',
      'amount': amount,
      'currency': 'COP',
      'scope': 'Cambio de tubería',
      'conditions': 'Pago contra entrega',
      'agreedAt': '2026-10-25T15:00:00Z',
      'validUntil': '2026-10-23T15:00:00Z',
      'status': status,
      'statusName': statusName,
      'expired': expired,
      'respondedAt': null,
      'createdAt': '2026-10-22T12:00:00Z',
      'updatedAt': '2026-10-22T12:00:00Z',
    };

NewQuotation _new({int? cents = 15000050}) => NewQuotation(
      serviceRequestId: 'req-1',
      amountInCents: cents,
      scope: 'Cambio de tubería',
      conditions: 'Pago contra entrega',
      agreedAt: DateTime.parse('2026-10-25T10:00:00-05:00'),
      validUntil: DateTime.parse('2026-10-23T10:00:00-05:00'),
    );

void main() {
  test('lee la versión y si es la vigente (GC-427)', () async {
    final list = await _repository((_) async => _json(200, [
          {..._quotationJson(id: 'q-2'), 'revision': 2, 'current': true},
          {
            ..._quotationJson(id: 'q-1', status: 'SUPERSEDED'),
            'revision': 1,
            'current': false,
          },
          _quotationJson(id: 'q-0'),
        ])).listForRequest('req-1');

    expect(list.map((q) => q.revision), [2, 1, null]);
    expect(list[0].isCurrent, isTrue);
    expect(list[0].versionLabel, 'Versión 2');
    expect(list[1].isCurrent, isFalse);
    // Sin el campo del backend se deduce del estado.
    expect(list[2].current, isNull);
    expect(list[2].isCurrent, isTrue);
    expect(list[2].versionLabel, 'Cotización');
  });

  group('send (prestador)', () {
    test('envía la cotización y devuelve la enviada', () async {
      late http.Request sent;
      final quotation = await _repository((request) async {
        sent = request;
        return _json(201, _quotationJson());
      }).send(_new());

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'http://localhost/api/services/quotations');
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'serviceRequestId': 'req-1',
        'amount': 150000.5,
        'currency': 'COP',
        'scope': 'Cambio de tubería',
        'conditions': 'Pago contra entrega',
        'agreedAt': '2026-10-25T15:00:00.000Z',
        'validUntil': '2026-10-23T15:00:00.000Z',
      });
      expect(quotation.id, 'q-1');
      expect(quotation.amountInCents, 15000050);
      expect(quotation.status, QuotationStatus.sent);
      expect(quotation.statusName, 'Enviada');
      expect(quotation.isOpen, isTrue);
      expect(quotation.agreedAt, DateTime.utc(2026, 10, 25, 15));
    });

    test('un valor sin centavos se envía como entero', () async {
      late http.Request sent;
      await _repository((request) async {
        sent = request;
        return _json(201, _quotationJson());
      }).send(_new(cents: 15000000));

      expect(jsonDecode(sent.body)['amount'], 150000);
    });

    test('409: ya no puede cotizar (usa el detail del backend)', () async {
      await expectLater(
        _repository((_) async => _json(409, {
              'title': 'Cotización no permitida',
              'detail': 'La solicitud ya tiene una cotización aceptada',
            })).send(_new()),
        throwsA(_failure('La solicitud ya tiene una cotización aceptada')),
      );
    });

    test('409 sin detail usa el mensaje propio', () async {
      await expectLater(
        _repository((_) async => http.Response('', 409)).send(_new()),
        throwsA(_failure(HttpQuotationRepository.notAllowedMessage)),
      );
    });

    test('400 por campo y por regla de negocio', () async {
      await expectLater(
        _repository((_) async => _json(400, {
              'errors': [
                {'field': 'amount', 'message': 'Máximo dos decimales'},
                {'field': 'amount', 'message': 'Otro'},
                {'field': 'x', 'message': ''},
                'basura',
              ],
            })).send(_new()),
        throwsA(_failure(HttpQuotationRepository.invalidDataMessage).having(
            (f) => f.fieldErrors,
            'fieldErrors',
            {'amount': 'Máximo dos decimales'})),
      );
      await expectLater(
        _repository((_) async => _json(400, {
              'detail':
                  'La vigencia no puede ser posterior a la fecha acordada',
            })).send(_new()),
        throwsA(
            _failure('La vigencia no puede ser posterior a la fecha acordada')),
      );
    });

    test('respuesta sin cotización válida es un error', () async {
      await expectLater(
        _repository((_) async => _json(201, {'id': 'q-1'})).send(_new()),
        throwsA(_failure(HttpQuotationRepository.unexpectedErrorMessage)),
      );
    });
  });

  group('consultas del prestador', () {
    test('lista las suyas y descarta las que no entiende', () async {
      late http.Request sent;
      final list = await _repository((request) async {
        sent = request;
        return _json(200, [
          _quotationJson(id: 'q-2', status: 'SUPERSEDED', statusName: null),
          _quotationJson(id: 'q-1', expired: true, amount: 150000),
          _quotationJson(id: 'q-3', status: 'NUEVO'),
          {..._quotationJson(id: 'q-4'), 'amount': '150000'},
          {..._quotationJson(id: 'q-5'), 'agreedAt': 'mal'},
          'basura',
        ]);
      }).listMine();

      expect(sent.url.toString(), 'http://localhost/api/services/quotations');
      expect(list.map((q) => q.id), ['q-2', 'q-1']);
      expect(list.first.statusName, 'Reemplazada',
          reason: 'sin statusName usa el nombre local');
      expect(list.last.isExpired, isTrue);
      expect(list.last.isOpen, isFalse);
      expect(list.last.amountInCents, 15000000);
      expect(() => (list as List).add(list.first), throwsUnsupportedError);
    });

    test('filtra por solicitud', () async {
      late http.Request sent;
      await _repository((request) async {
        sent = request;
        return _json(200, []);
      }).listMine(serviceRequestId: 'req-1');

      expect(sent.url.queryParameters, {'serviceRequestId': 'req-1'});
    });

    test('consulta una por id y 404 si no es suya', () async {
      late http.Request sent;
      final q = await _repository((request) async {
        sent = request;
        return _json(200, _quotationJson(id: 'abc'));
      }).getMine('abc');
      expect(
          sent.url.toString(), 'http://localhost/api/services/quotations/abc');
      expect(q.id, 'abc');

      await expectLater(
        _repository((_) async => _json(404, {})).getMine('abc'),
        throwsA(_failure(HttpQuotationRepository.notFoundMessage)),
      );
    });

    test('campos opcionales raros no rompen', () async {
      final q = await _repository((_) async => _json(200, {
            ..._quotationJson(),
            'currency': null,
            'scope': 7,
            'conditions': null,
            'expired': 'sí',
            'respondedAt': '2026-10-22T13:00:00Z',
          })).getMine('q-1');

      expect(q.currency, 'COP');
      expect(q.scope, '');
      expect(q.conditions, '');
      expect(q.isExpired, isFalse);
      expect(q.respondedAt, DateTime.utc(2026, 10, 22, 13));
    });
  });

  group('consulta del cliente', () {
    test('lista las cotizaciones de su solicitud', () async {
      late http.Request sent;
      final list = await _repository((request) async {
        sent = request;
        return _json(200, [_quotationJson()]);
      }).listForRequest('req-1');

      expect(sent.url.toString(),
          'http://localhost/api/services/requests/req-1/quotations');
      expect(list.single.id, 'q-1');
    });

    test('404: la solicitud no es suya', () async {
      await expectLater(
        _repository((_) async => _json(404, {})).listForRequest('req-1'),
        throwsA(_failure(HttpQuotationRepository.notFoundMessage)),
      );
    });
  });

  group('respuesta del cliente (GC-361)', () {
    for (final (decision, status, path) in [
      ('accept', 'ACCEPTED', 'acceptance'),
      ('reject', 'REJECTED', 'rejection'),
    ]) {
      test('$decision: POST a /$path y devuelve la cotización', () async {
        late http.Request sent;
        final repository = _repository((request) async {
          sent = request;
          return _json(200, _quotationJson(status: status, statusName: null));
        });

        final quotation = decision == 'accept'
            ? await repository.accept('req-1', 'q-1')
            : await repository.reject('req-1', 'q-1');

        expect(sent.method, 'POST');
        expect(
          sent.url.toString(),
          'http://localhost/api/services/requests/req-1/quotations/q-1/$path',
        );
        expect(sent.headers['Authorization'], 'Bearer token-1');
        expect(quotation.status.apiValue, status);
      });
    }

    test('409: usa el motivo del backend', () async {
      final repository = _repository((_) async => _json(409, {
            'detail': 'La solicitud ya tiene una cotización aceptada',
          }));

      await expectLater(
        repository.accept('req-1', 'q-1'),
        throwsA(_failure('La solicitud ya tiene una cotización aceptada')),
      );
    });

    test('409 sin motivo explica que ya no se puede responder', () async {
      final repository = _repository((_) async => _json(409, {}));

      await expectLater(
        repository.reject('req-1', 'q-1'),
        throwsA(_failure(HttpQuotationRepository.responseNotAllowedMessage)),
      );
    });

    test('404: la cotización o la solicitud no es suya', () async {
      final repository = _repository((_) async => _json(404, {}));

      await expectLater(
        repository.accept('req-1', 'q-x'),
        throwsA(_failure(HttpQuotationRepository.notFoundMessage)),
      );
    });

    test('200 sin una cotización válida es un error', () async {
      final repository = _repository((_) async => _json(200, {'id': 'q-1'}));

      await expectLater(
        repository.accept('req-1', 'q-1'),
        throwsA(_failure(HttpQuotationRepository.unexpectedErrorMessage)),
      );
    });
  });

  group('errores comunes', () {
    for (final (status, message) in [
      (403, HttpQuotationRepository.forbiddenMessage),
      (500, HttpQuotationRepository.unexpectedErrorMessage),
    ]) {
      test('$status se traduce a un mensaje claro', () async {
        await expectLater(
          _repository((_) async => _json(status, {})).listMine(),
          throwsA(_failure(message)),
        );
      });
    }

    test('una lista que no es lista o no es JSON es un error', () async {
      for (final response in [_json(200, {}), http.Response('<html>', 200)]) {
        await expectLater(
          _repository((_) async => response).listMine(),
          throwsA(_failure(HttpQuotationRepository.unexpectedErrorMessage)),
        );
      }
    });

    test('si la sesión no se puede renovar, la sesión expiró', () async {
      await expectLater(
        _repository((_) async => http.Response('', 401)).listMine(),
        throwsA(_failure(HttpQuotationRepository.sessionExpiredMessage)
            .having((f) => f.isSessionExpired, 'isSessionExpired', isTrue)),
      );
    });

    test('sin red se pide revisar la conexión', () async {
      await expectLater(
        _repository((_) => throw http.ClientException('sin red')).send(_new()),
        throwsA(_failure(HttpQuotationRepository.connectionErrorMessage)),
      );
    });
  });
}
