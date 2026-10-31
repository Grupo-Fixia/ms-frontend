import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/company/technicians/domain/associated_technician.dart';
import 'package:ms_frontend/features/company/technicians/domain/company_exceptions.dart';
import 'package:ms_frontend/features/company/technicians/infrastructure/http_company_repository.dart';

const _company = 'http://localhost/api/users/companies/me';
const _technicians = 'http://localhost/api/users/companies/me/technicians';

/// Respuesta como la de ms-users: JSON en UTF-8 sin charset en el header.
http.Response _json(int status, Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpCompanyRepository _repository(
  MockClientHandler handler, {
  String? token = 'token-1',
  bool canRenew = false,
}) =>
    HttpCompanyRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
        accessToken: () => token,
        renewSession: () async => canRenew,
      ),
    );

Matcher _failure(String message, {bool isSessionExpired = false}) =>
    isA<CompanyFailure>()
        .having((f) => f.message, 'message', message)
        .having((f) => f.isSessionExpired, 'isSessionExpired', isSessionExpired);

void main() {
  group('getMine', () {
    test('consulta la empresa del token, sin enviar ningún id de empresa',
        () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json(200, {
          'id': 'c0a00000-0000-4000-8000-000000000001',
          'name': 'Servicios Integrales Andina',
          'nit': '900123456-7',
        });
      });

      final company = await repository.getMine();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), _company);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(company.id, 'c0a00000-0000-4000-8000-000000000001');
      expect(company.name, 'Servicios Integrales Andina');
      expect(company.nit, '900123456-7');
    });

    test('un NIT vacío o ausente queda en null', () async {
      final repository =
          _repository((_) async => _json(200, {'id': 'c-1', 'name': 'Andina'}));

      expect((await repository.getMine()).nit, isNull);
    });

    test('una respuesta sin nombre es un error, no una empresa inventada',
        () async {
      final repository =
          _repository((_) async => _json(200, {'id': 'c-1', 'name': ' '}));

      await expectLater(repository.getMine(),
          throwsA(_failure(HttpCompanyRepository.unexpectedErrorMessage)));
    });

    test('404: la cuenta no administra ninguna empresa', () async {
      final repository = _repository((_) async => _json(404, {}));

      await expectLater(repository.getMine(),
          throwsA(_failure(HttpCompanyRepository.notFoundMessage)));
    });
  });

  group('listTechnicians', () {
    test('devuelve los técnicos con sus datos públicos y tildes intactas',
        () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json(200, {
          'technicians': [
            {
              'userId': '7ec00000-0000-4000-8000-000000000001',
              'displayName': 'Carlos Giraldo',
              'verificationStatus': 'VALID',
              'categories': ['PLUMBING', 'ELECTRICAL', 'DESCONOCIDA'],
              'professionalDescription': 'Instalaciones y reparaciones',
              'yearsOfExperience': 6,
              'city': 'Bogotá',
            },
            {
              'userId': '7ec00000-0000-4000-8000-000000000002',
              'displayName': null,
              'verificationStatus': null,
              'categories': [],
              'professionalDescription': null,
              'yearsOfExperience': null,
              'city': null,
            },
          ],
        });
      });

      final technicians = await repository.listTechnicians();

      expect(sent.url.toString(), _technicians);
      expect(sent.headers['Authorization'], 'Bearer token-1');
      expect(technicians, hasLength(2));
      final first = technicians.first;
      expect(first.userId, '7ec00000-0000-4000-8000-000000000001');
      expect(first.name, 'Carlos Giraldo');
      expect(first.isVerified, isTrue);
      expect(first.categories,
          [ServiceCategory.plumbing, ServiceCategory.electrical]);
      expect(first.yearsOfExperience, 6);
      expect(first.city, 'Bogotá');
      final second = technicians.last;
      expect(second.displayName, isNull);
      expect(second.name, 'Técnico sin nombre público');
      expect(second.verificationStatus, isNull);
      expect(second.categories, isEmpty);
    });

    test('una empresa sin técnicos recibe la lista vacía', () async {
      final repository =
          _repository((_) async => _json(200, {'technicians': []}));

      expect(await repository.listTechnicians(), isEmpty);
    });

    test('descarta los elementos sin userId', () async {
      final repository = _repository((_) async => _json(200, {
            'technicians': [
              {'displayName': 'Sin id'},
              'no es un objeto',
              {'userId': 't-1', 'verificationStatus': 'PENDING'},
            ],
          }));

      final technicians = await repository.listTechnicians();

      expect(technicians.map((t) => t.userId), ['t-1']);
      expect(technicians.single.verificationStatus, VerificationStatus.pending);
    });

    test('una respuesta sin la lista es un error', () async {
      final repository = _repository((_) async => _json(200, {'otra': 1}));

      await expectLater(repository.listTechnicians(),
          throwsA(_failure(HttpCompanyRepository.unexpectedErrorMessage)));
    });

    test('403: el rol no es de empresa', () async {
      final repository = _repository((_) async => _json(403, {}));

      await expectLater(repository.listTechnicians(),
          throwsA(_failure(HttpCompanyRepository.forbiddenMessage)));
    });

    test('500 u otro estado: error genérico', () async {
      final repository = _repository((_) async => _json(500, {}));

      await expectLater(repository.listTechnicians(),
          throwsA(_failure(HttpCompanyRepository.unexpectedErrorMessage)));
    });

    test('401 sin poder renovar: la sesión venció', () async {
      final repository = _repository((_) async => _json(401, {}));

      await expectLater(
        repository.listTechnicians(),
        throwsA(_failure(HttpCompanyRepository.sessionExpiredMessage,
            isSessionExpired: true)),
      );
    });

    test('sin token: la sesión venció sin llamar al backend', () async {
      var calls = 0;
      final repository = _repository((_) async {
        calls++;
        return _json(200, {'technicians': []});
      }, token: null);

      await expectLater(
        repository.listTechnicians(),
        throwsA(_failure(HttpCompanyRepository.sessionExpiredMessage,
            isSessionExpired: true)),
      );
      expect(calls, 0);
    });

    test('sin red: problema de conexión, sin cerrar la sesión', () async {
      final repository = _repository(
          (_) async => throw http.ClientException('sin red'));

      await expectLater(repository.listTechnicians(),
          throwsA(_failure(HttpCompanyRepository.connectionErrorMessage)));
    });

    test('un cuerpo que no es JSON es un error', () async {
      final repository =
          _repository((_) async => http.Response('<html>', 200));

      await expectLater(repository.listTechnicians(),
          throwsA(_failure(HttpCompanyRepository.unexpectedErrorMessage)));
    });
  });
}
