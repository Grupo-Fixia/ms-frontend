import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/technician/company/domain/technician_company.dart';
import 'package:ms_frontend/features/technician/company/infrastructure/http_technician_company_repository.dart';

http.Response _json(int status, Object? body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json'});

HttpTechnicianCompanyRepository _repo(MockClientHandler handler) =>
    HttpTechnicianCompanyRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://users.local'),
      authorizedHttp: AuthorizedHttp(
          accessToken: () => 't', renewSession: () async => false),
    );

const _base = '/api/users/technicians/me';
const _membership = {
  'company': {'name': 'Soluciones Hogar Bogotá S.A.S.'},
  'joinedAt': '2026-11-21T15:00:00Z',
};

Matcher _failure(String message) => throwsA(
    isA<TechnicianCompanyFailure>().having((f) => f.message, 'msg', message));

void main() {
  test('lista sus invitaciones con el nombre de la empresa', () async {
    late http.Request asked;
    final repo = _repo((r) async {
      asked = r;
      return _json(200, {
        'invitations': [
          {
            'id': 'i1',
            'status': 'PENDING',
            'company': {'name': 'Soluciones Hogar'},
            'createdAt': '2026-11-21T15:00:00Z',
            'expiresAt': '2026-11-28T15:00:00Z',
            'respondedAt': null,
          },
          {'id': 'rota'},
        ],
      });
    });
    final items = await repo.invitations();
    expect(asked.method, 'GET');
    expect(asked.url.path, '$_base/invitations');
    expect(asked.headers['Authorization'], 'Bearer t');
    expect(items.single.companyName, 'Soluciones Hogar');
    expect(items.single.expiresAt, DateTime.utc(2026, 11, 28, 15));
  });

  test('aceptar devuelve la empresa', () async {
    late http.Request asked;
    final repo = _repo((r) async {
      asked = r;
      return _json(200, _membership);
    });
    final m = await repo.accept('i1');
    expect(asked.method, 'POST');
    expect(asked.url.path, '$_base/invitations/i1/accept');
    expect(m.companyName, 'Soluciones Hogar Bogotá S.A.S.');
    expect(m.joinedAt, DateTime.utc(2026, 11, 21, 15));
  });

  test('aceptar: cada 409 con su mensaje', () async {
    for (final (reason, message) in [
      (
        'INVITATION_NOT_PENDING',
        HttpTechnicianCompanyRepository.notPendingMessage
      ),
      (
        'ALREADY_IN_COMPANY',
        HttpTechnicianCompanyRepository.alreadyInCompanyMessage
      ),
      (
        'COMPANY_UNAVAILABLE',
        HttpTechnicianCompanyRepository.companyUnavailableMessage
      ),
    ]) {
      await expectLater(
        _repo((_) async => _json(409, {
              'reasons': [reason]
            })).accept('i1'),
        _failure(message),
      );
    }
  });

  test('rechazar', () async {
    late http.Request asked;
    await _repo((r) async {
      asked = r;
      return _json(200, {'id': 'i1', 'status': 'REJECTED'});
    }).reject('i1');
    expect(asked.method, 'POST');
    expect(asked.url.path, '$_base/invitations/i1/reject');
  });

  test('su empresa; 404 es independiente', () async {
    final member = await _repo((r) async {
      expect(r.url.path, '$_base/company');
      return _json(200, _membership);
    }).membership();
    expect(member!.companyName, 'Soluciones Hogar Bogotá S.A.S.');
    expect(await _repo((_) async => _json(404, {})).membership(), isNull);
  });

  test('desvincularse: 204', () async {
    late http.Request asked;
    await _repo((r) async {
      asked = r;
      return http.Response('', 204);
    }).leave();
    expect(asked.method, 'DELETE');
    expect(asked.url.path, '$_base/company');
  });

  test('desvincularse: 409 trae los motivos y los servicios', () async {
    await expectLater(
      _repo((_) async => _json(409, {
            'reasons': ['PENDING_WORK', 'HELD_BALANCE', 'OTRO'],
            'serviceRequestIds': ['s1', 's2'],
          })).leave(),
      throwsA(isA<TechnicianCompanyFailure>()
          .having((f) => f.statusCode, 'status', 409)
          .having((f) => f.blockers, 'blockers', [
        LeaveBlocker.pendingWork,
        LeaveBlocker.heldBalance
      ]).having((f) => f.serviceRequestIds, 'ids', ['s1', 's2'])),
    );
  });

  test('desvincularse: 503 no se pudo verificar; 404 ya es independiente',
      () async {
    await expectLater(_repo((_) async => _json(503, {})).leave(),
        _failure(HttpTechnicianCompanyRepository.leaveUnverifiedMessage));
    await expectLater(_repo((_) async => _json(404, {})).leave(),
        _failure(HttpTechnicianCompanyRepository.notMemberMessage));
  });

  test('errores comunes', () async {
    await expectLater(_repo((_) async => _json(403, {})).invitations(),
        _failure(HttpTechnicianCompanyRepository.forbiddenMessage));
    await expectLater(_repo((_) async => _json(500, {})).invitations(),
        _failure(HttpTechnicianCompanyRepository.unavailableMessage));
    await expectLater(
        _repo((_) async => throw http.ClientException('caído')).membership(),
        _failure(HttpTechnicianCompanyRepository.connectionErrorMessage));
    await expectLater(_repo((_) async => _json(200, {'x': 1})).membership(),
        _failure(HttpTechnicianCompanyRepository.unavailableMessage));
    await expectLater(
        _repo((_) async => _json(401, {})).invitations(),
        throwsA(isA<TechnicianCompanyFailure>()
            .having((f) => f.isSessionExpired, 'expired', isTrue)));
  });
}
