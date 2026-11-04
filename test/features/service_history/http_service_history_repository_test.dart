import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/service_history/domain/service_evaluation.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_entry.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_exceptions.dart';
import 'package:ms_frontend/features/service_history/infrastructure/http_service_history_repository.dart';

http.Response _json(int status, Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

AuthorizedHttp _auth({String? token = 'token-1'}) => AuthorizedHttp(
      accessToken: () => token,
      renewSession: () async => false,
    );

HttpServiceHistoryRepository _history(MockClientHandler handler,
        {String? token = 'token-1'}) =>
    HttpServiceHistoryRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: _auth(token: token),
    );

HttpServiceEvaluationRepository _evaluations(MockClientHandler handler) =>
    HttpServiceEvaluationRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: _auth(),
    );

Map<String, Object?> _item({
  String id = '1',
  String status = 'CLOSED',
  String role = 'CLIENT',
  Object? amount = 180000.5,
  Object? budget = 200000,
  String? startedAt = '2026-10-26T13:00:00Z',
}) =>
    {
      'serviceRequestId': 'req-$id',
      'contractId': 'con-$id',
      'role': role,
      'counterpartId': 'tec-1',
      'category': 'PLUMBING',
      'status': status,
      'budgetAmount': budget,
      'contractedAmount': amount,
      'currency': 'COP',
      'agreedAt': '2026-10-28T15:00:00Z',
      'contractedAt': '2026-10-25T14:00:00Z',
      'startedAt': startedAt,
      'finishedAt': null,
      'closedAt': '2026-10-30T18:00:00Z',
      'lastTransitionAt': '2026-10-30T18:00:00Z',
    };

TypeMatcher<ServiceHistoryFailure> _failure(String message,
        {bool isSessionExpired = false}) =>
    isA<ServiceHistoryFailure>()
        .having((f) => f.message, 'message', message)
        .having(
            (f) => f.isSessionExpired, 'isSessionExpired', isSessionExpired);

void main() {
  group('historial', () {
    test('pide la primera página con el token y la convierte', () async {
      late http.Request sent;
      final repository = _history((request) async {
        sent = request;
        return _json(200, {
          'items': [_item()],
          'nextCursor': 'abc',
        });
      });

      final page = await repository.listPage(limit: 20);

      expect(sent.url.path, '/api/services/history');
      expect(sent.url.queryParameters, {'limit': '20'});
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(page.nextCursor, 'abc');
      expect(page.hasMore, isTrue);
      final entry = page.items.single;
      expect(entry.serviceRequestId, 'req-1');
      expect(entry.contractId, 'con-1');
      expect(entry.role, HistoryRole.client);
      expect(entry.category, ServiceCategory.plumbing);
      expect(entry.status, ServiceRequestStatus.closed);
      expect(entry.stage, HistoryStage.closed);
      expect(entry.contractedAmount.label, '180.000,5 COP');
      expect(entry.budget?.label, '200.000 COP');
      expect(entry.startedAt, DateTime.utc(2026, 10, 26, 13).toLocal());
      expect(entry.finishedAt, isNull);
    });

    test('envía el cursor y reconoce la última página', () async {
      late http.Request sent;
      final repository = _history((request) async {
        sent = request;
        return _json(200, {'items': [], 'nextCursor': null});
      });

      final page = await repository.listPage(cursor: 'abc', limit: 10);

      expect(sent.url.queryParameters, {'limit': '10', 'cursor': 'abc'});
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('descarta elementos incompletos sin inventar datos', () async {
      final repository = _history((_) async => _json(200, {
            'items': [
              _item(id: 'ok', budget: null, startedAt: null),
              {..._item(id: 'sin-rol'), 'role': 'COMPANY'},
              {..._item(id: 'sin-ids'), 'contractId': null},
              _item(id: 'monto-malo', amount: 'mucho'),
              {..._item(id: 'sin-fecha'), 'contractedAt': 'ayer'},
              'no es un objeto',
            ],
            'nextCursor': null,
          }));

      final items = (await repository.listPage()).items;

      expect(items.map((e) => e.serviceRequestId), ['req-ok']);
      expect(items.single.budget, isNull);
      expect(items.single.startedAt, isNull);
    });

    test('un estado desconocido queda sin estado y en «otros»', () async {
      final repository = _history((_) async => _json(200, {
            'items': [_item(status: 'NUEVO_ESTADO')],
            'nextCursor': null,
          }));

      final entry = (await repository.listPage()).items.single;

      expect(entry.status, isNull);
      expect(entry.stage, HistoryStage.other);
    });

    test('403: rol sin historial', () async {
      final repository = _history((_) async => _json(403, {}));

      await expectLater(repository.listPage(),
          throwsA(_failure(HttpServiceHistoryRepository.forbiddenMessage)));
    });

    test('400 u otro estado, o respuesta sin lista: error genérico', () async {
      for (final response in [
        _json(400, {}),
        _json(500, {}),
        _json(200, {'otra': 1}),
        http.Response('<html>', 200),
      ]) {
        final repository = _history((_) async => response);
        await expectLater(
            repository.listPage(),
            throwsA(
                _failure(HttpServiceHistoryRepository.unexpectedErrorMessage)));
      }
    });

    test('401 sin poder renovar o sin token: sesión vencida', () async {
      await expectLater(
        _history((_) async => _json(401, {})).listPage(),
        throwsA(_failure(HttpServiceHistoryRepository.sessionExpiredMessage,
            isSessionExpired: true)),
      );
      await expectLater(
        _history((_) async => _json(200, {}), token: null).listPage(),
        throwsA(_failure(HttpServiceHistoryRepository.sessionExpiredMessage,
            isSessionExpired: true)),
      );
    });

    test('sin red: problema de conexión', () async {
      final repository =
          _history((_) async => throw http.ClientException('sin red'));

      await expectLater(
          repository.listPage(),
          throwsA(
              _failure(HttpServiceHistoryRepository.connectionErrorMessage)));
    });
  });

  group('evaluaciones', () {
    test('pide los ids separados por coma y convierte las evaluaciones',
        () async {
      late http.Request sent;
      final repository = _evaluations((request) async {
        sent = request;
        return _json(200, {
          'items': [
            {
              'id': 'ev-1',
              'serviceRequestId': 'req-1',
              'direction': 'CLIENT_TO_PROVIDER',
              'evaluatorId': 'cli-1',
              'evaluatedId': 'tec-1',
              'rating': 4,
              'comment': 'Muy puntual, quedó perfecto',
              'source': 'CONFIRMED_CLOSURE',
              'createdAt': '2026-10-31T10:00:00Z',
            },
          ],
        });
      });

      final evaluations = await repository.listFor(['req-1', 'req-2']);

      expect(sent.url.path, '/api/users/evaluations');
      expect(sent.url.queryParameters, {'serviceRequestIds': 'req-1,req-2'});
      expect(sent.headers['Authorization'], 'Bearer token-1');
      final evaluation = evaluations.single;
      expect(evaluation.direction, EvaluationDirection.clientToProvider);
      expect(evaluation.rating, 4);
      expect(evaluation.comment, 'Muy puntual, quedó perfecto');
      expect(evaluation.isBy('cli-1'), isTrue);
      expect(evaluation.isFor('tec-1'), isTrue);
      expect(evaluation.createdAt, isNotNull);
    });

    test('sin ids no llama al backend', () async {
      var calls = 0;
      final repository = _evaluations((_) async {
        calls++;
        return _json(200, {'items': []});
      });

      expect(await repository.listFor(const []), isEmpty);
      expect(calls, 0);
    });

    test('descarta evaluaciones fuera de rango o incompletas', () async {
      final repository = _evaluations((_) async => _json(200, {
            'items': [
              {
                'serviceRequestId': 'req-1',
                'direction': 'PROVIDER_TO_CLIENT',
                'evaluatorId': 'tec-1',
                'evaluatedId': 'cli-1',
                'rating': 6,
              },
              {
                'serviceRequestId': 'req-1',
                'direction': 'OTRA',
                'evaluatorId': 'tec-1',
                'evaluatedId': 'cli-1',
                'rating': 3,
              },
              {
                'serviceRequestId': 'req-1',
                'direction': 'PROVIDER_TO_CLIENT',
                'evaluatorId': 'tec-1',
                'evaluatedId': 'cli-1',
                'rating': 3,
                'comment': ' ',
              },
              'x',
            ],
          }));

      final evaluations = await repository.listFor(['req-1']);

      expect(evaluations.single.rating, 3);
      expect(
          evaluations.single.direction, EvaluationDirection.providerToClient);
      expect(evaluations.single.comment, isNull);
    });

    test('un error del backend es un fallo de evaluaciones', () async {
      for (final response in [
        _json(400, {}),
        _json(200, {'x': 1})
      ]) {
        final repository = _evaluations((_) async => response);
        await expectLater(
            repository.listFor(['req-1']),
            throwsA(_failure(
                HttpServiceEvaluationRepository.unexpectedErrorMessage)));
      }
    });
  });
  group('registrar evaluación', () {
    Map<String, Object?> saved({int rating = 4, String? comment = 'Puntual'}) =>
        {
          'id': 'eva-1',
          'serviceRequestId': 'req-1',
          'direction': 'CLIENT_TO_PROVIDER',
          'evaluatorId': 'cli-1',
          'evaluatedId': 'tec-1',
          'rating': rating,
          'comment': comment,
          'source': 'CONFIRMED_CLOSURE',
          'createdAt': '2026-11-03T15:00:00Z',
        };

    test('envía servicio, nota y comentario sin espacios y con el token',
        () async {
      late http.Request sent;
      final repository = _evaluations((request) async {
        sent = request;
        return _json(201, saved());
      });

      final evaluation = await repository.submit(NewServiceEvaluation(
          serviceRequestId: 'req-1', rating: 4, comment: '  Puntual  '));

      expect(sent.method, 'POST');
      expect(sent.url.path, HttpServiceEvaluationRepository.path);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body),
          {'serviceRequestId': 'req-1', 'rating': 4, 'comment': 'Puntual'});
      expect(evaluation.rating, 4);
      expect(evaluation.evaluatorId, 'cli-1');
      expect(evaluation.direction, EvaluationDirection.clientToProvider);
    });

    test('sin comentario no lo envía; un reintento idéntico (200) sirve',
        () async {
      late http.Request sent;
      final repository = _evaluations((request) async {
        sent = request;
        return _json(200, saved(rating: 5, comment: null));
      });

      final evaluation = await repository.submit(NewServiceEvaluation(
          serviceRequestId: 'req-1', rating: 5, comment: '   '));

      expect(jsonDecode(sent.body), {'serviceRequestId': 'req-1', 'rating': 5});
      expect(evaluation.comment, isNull);
    });

    test('una confirmación que no coincide no se da por buena', () async {
      for (final body in [
        saved(rating: 3),
        {...saved(), 'serviceRequestId': 'req-2'},
        {'x': 1},
      ]) {
        final repository = _evaluations((_) async => _json(201, body));
        await expectLater(
            repository.submit(
                NewServiceEvaluation(serviceRequestId: 'req-1', rating: 4)),
            throwsA(_failure(
                HttpServiceEvaluationRepository.unconfirmedSubmissionMessage)));
      }
    });

    test('409: ya había calificado', () async {
      final repository = _evaluations((_) async => _json(409, {
            'reasons': ['EVALUATION_ALREADY_EXISTS']
          }));

      await expectLater(
          repository.submit(
              NewServiceEvaluation(serviceRequestId: 'req-1', rating: 4)),
          throwsA(
              _failure(HttpServiceEvaluationRepository.alreadyEvaluatedMessage)
                  .having(
                      (f) => f.alreadyEvaluated, 'alreadyEvaluated', isTrue)));
    });

    test('422: explica cada motivo del servidor y no deja reintentar',
        () async {
      for (final entry
          in HttpServiceEvaluationRepository.rejectionMessages.entries) {
        final repository = _evaluations((_) async => _json(422, {
              'reasons': [entry.key]
            }));
        await expectLater(
            repository.submit(
                NewServiceEvaluation(serviceRequestId: 'req-1', rating: 4)),
            throwsA(_failure(entry.value)
                .having((f) => f.notAllowed, 'notAllowed', isTrue)));
      }
      final unknown = _evaluations((_) async => _json(422, {
            'reasons': ['OTRO']
          }));
      await expectLater(
          unknown.submit(
              NewServiceEvaluation(serviceRequestId: 'req-1', rating: 4)),
          throwsA(_failure(HttpServiceEvaluationRepository.notAllowedMessage)));
    });

    test('400, 403, 404, 503 y otros códigos con su mensaje', () async {
      final cases = {
        400: HttpServiceEvaluationRepository.invalidSubmissionMessage,
        403: HttpServiceEvaluationRepository.forbiddenSubmissionMessage,
        404: HttpServiceEvaluationRepository.notFoundSubmissionMessage,
        503: HttpServiceEvaluationRepository.verificationUnavailableMessage,
        500: HttpServiceEvaluationRepository.unconfirmedSubmissionMessage,
      };
      for (final entry in cases.entries) {
        final repository =
            _evaluations((_) async => _json(entry.key, {'detail': 'x'}));
        await expectLater(
            repository.submit(
                NewServiceEvaluation(serviceRequestId: 'req-1', rating: 4)),
            throwsA(_failure(entry.value)));
      }
    });

    test('401 sin poder renovar: sesión vencida', () async {
      final repository = _evaluations((_) async => _json(401, {}));

      await expectLater(
          repository.submit(
              NewServiceEvaluation(serviceRequestId: 'req-1', rating: 4)),
          throwsA(_failure(HttpServiceHistoryRepository.sessionExpiredMessage,
              isSessionExpired: true)));
    });
  });

  group('NewServiceEvaluation', () {
    test('valida la nota y el largo del comentario', () {
      expect(() => NewServiceEvaluation(serviceRequestId: 'r', rating: 0),
          throwsArgumentError);
      expect(() => NewServiceEvaluation(serviceRequestId: 'r', rating: 6),
          throwsArgumentError);
      expect(
          () => NewServiceEvaluation(
              serviceRequestId: 'r', rating: 5, comment: 'a' * 501),
          throwsArgumentError);
      expect(
          NewServiceEvaluation(
                  serviceRequestId: 'r', rating: 5, comment: 'a' * 500)
              .comment,
          hasLength(500));
    });
  });
}
