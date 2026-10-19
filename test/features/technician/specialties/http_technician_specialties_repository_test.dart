import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/technician/specialties/domain/technician_specialties_exceptions.dart';
import 'package:ms_frontend/features/technician/specialties/infrastructure/http_technician_specialties_repository.dart';

const _catalog = 'http://localhost/api/users/service-categories';
const _mine = 'http://localhost/api/users/technicians/me/categories';

/// Respuesta como la de ms-users: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpTechnicianSpecialtiesRepository _repository(
  MockClientHandler handler, {
  String? token = 'token-1',
  bool canRenew = false,
}) =>
    HttpTechnicianSpecialtiesRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => token,
        renewSession: () async => canRenew,
      ),
    );

Matcher _failure({
  String? message,
  Map<String, String>? fieldErrors,
  bool isSessionExpired = false,
}) {
  var matcher = isA<TechnicianSpecialtiesFailure>().having(
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

void main() {
  group('fetchCatalog', () {
    test('consulta el catálogo con el token y usa los nombres del backend',
        () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json(200, [
          {'code': 'PLUMBING', 'name': 'Plomería'},
          {'code': 'ELECTRICAL', 'name': 'Electricidad residencial'},
        ]);
      });

      final options = await repository.fetchCatalog();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), _catalog);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(options.map((o) => o.category),
          [ServiceCategory.plumbing, ServiceCategory.electrical]);
      expect(
          options.map((o) => o.name), ['Plomería', 'Electricidad residencial']);
    });

    test('ignora categorías desconocidas y usa el nombre local si falta',
        () async {
      final options = await _repository((_) async => _json(200, [
            {'code': 'GARDENING', 'name': 'Jardinería'},
            {'code': 7, 'name': 'Código que no es texto'},
            {'code': 'PAINTING', 'name': '  '},
            'basura',
          ])).fetchCatalog();

      expect(options, hasLength(1));
      expect(options.single.category, ServiceCategory.painting);
      expect(options.single.name, ServiceCategory.painting.label);
    });

    test('si la respuesta no es una lista, falla con un error genérico',
        () async {
      await expectLater(
        _repository((_) async => _json(200, {'x': 1})).fetchCatalog(),
        throwsA(_failure(
          message: HttpTechnicianSpecialtiesRepository.unexpectedErrorMessage,
        )),
      );
    });
  });

  group('fetchSpecialties', () {
    test('devuelve las especialidades guardadas', () async {
      late http.Request sent;
      final specialties = await _repository((request) async {
        sent = request;
        return _json(200, {
          'categories': ['PAINTING', 'PLUMBING', 'DESCONOCIDA'],
          'updatedAt': '2026-10-18T15:30:00Z',
        });
      }).fetchSpecialties();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), _mine);
      expect(specialties.categories,
          {ServiceCategory.painting, ServiceCategory.plumbing});
      expect(specialties.updatedAt, DateTime.utc(2026, 10, 18, 15, 30));
    });

    test('sin selección devuelve un conjunto vacío', () async {
      final specialties = await _repository(
        (_) async => _json(200, {'categories': [], 'updatedAt': null}),
      ).fetchSpecialties();

      expect(specialties.categories, isEmpty);
      expect(specialties.updatedAt, isNull);
    });

    test('si falta la lista de categorías, falla con un error genérico',
        () async {
      await expectLater(
        _repository((_) async => http.Response('no-json', 200))
            .fetchSpecialties(),
        throwsA(_failure(
          message: HttpTechnicianSpecialtiesRepository.unexpectedErrorMessage,
        )),
      );
    });
  });

  test('si el objeto no trae la lista de categorías, falla', () async {
    await expectLater(
      _repository((_) async => _json(200, {'categories': 'PLUMBING'}))
          .fetchSpecialties(),
      throwsA(_failure(
        message: HttpTechnicianSpecialtiesRepository.unexpectedErrorMessage,
      )),
    );
  });

  group('updateSpecialties', () {
    test('envía la selección en el orden del catálogo y devuelve lo guardado',
        () async {
      late http.Request sent;
      final saved = await _repository((request) async {
        sent = request;
        return _json(200, {
          'categories': ['PLUMBING', 'CARPENTRY'],
          'updatedAt': '2026-10-18T16:00:00Z',
        });
      }).updateSpecialties(
        {ServiceCategory.carpentry, ServiceCategory.plumbing},
      );

      expect(sent.method, 'PUT');
      expect(sent.url.toString(), _mine);
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'categories': ['PLUMBING', 'CARPENTRY'],
      });
      expect(saved.categories,
          {ServiceCategory.plumbing, ServiceCategory.carpentry});
    });

    test('una selección vacía las retira todas', () async {
      late http.Request sent;
      await _repository((request) async {
        sent = request;
        return _json(200, {'categories': []});
      }).updateSpecialties({});

      expect(jsonDecode(sent.body), {'categories': []});
    });

    test('400 trae los errores agrupados por campo', () async {
      await expectLater(
        _repository((_) async => _json(400, {
              'errors': [
                {'field': 'categories[0]', 'message': 'No válida'},
                {'field': 'categories[1]', 'message': 'Otra'},
                {'field': 'x', 'message': ' '},
                'basura',
              ],
            })).updateSpecialties({ServiceCategory.plumbing}),
        throwsA(_failure(
          message: HttpTechnicianSpecialtiesRepository.invalidDataMessage,
          fieldErrors: {'categories': 'No válida'},
        )),
      );
    });
  });

  group('errores comunes', () {
    for (final (status, message) in [
      (403, HttpTechnicianSpecialtiesRepository.forbiddenMessage),
      (404, HttpTechnicianSpecialtiesRepository.notFoundMessage),
      (500, HttpTechnicianSpecialtiesRepository.unexpectedErrorMessage),
    ]) {
      test('$status se traduce a un mensaje claro', () async {
        await expectLater(
          _repository((_) async => _json(status, {})).fetchSpecialties(),
          throwsA(_failure(message: message)),
        );
      });
    }

    test('si la sesión no se puede renovar, la sesión expiró', () async {
      await expectLater(
        _repository((_) async => http.Response('', 401)).fetchCatalog(),
        throwsA(_failure(
          message: HttpTechnicianSpecialtiesRepository.sessionExpiredMessage,
          isSessionExpired: true,
        )),
      );
    });

    test('sin red se pide revisar la conexión', () async {
      await expectLater(
        _repository((_) => throw http.ClientException('sin red'))
            .updateSpecialties({ServiceCategory.plumbing}),
        throwsA(_failure(
          message: HttpTechnicianSpecialtiesRepository.connectionErrorMessage,
        )),
      );
    });
  });

  test('la falla se muestra con su mensaje', () {
    expect(
      const TechnicianSpecialtiesFailure('Mensaje').toString(),
      'Mensaje',
    );
  });
}
