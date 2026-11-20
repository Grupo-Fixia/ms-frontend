import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/company/invitations/domain/company_invitation.dart';
import 'package:ms_frontend/features/company/invitations/infrastructure/http_company_invitations_repository.dart';

http.Response _json(int status, Object? body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json'});

HttpCompanyInvitationsRepository _repo(MockClientHandler handler) =>
    HttpCompanyInvitationsRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://users.local'),
      authorizedHttp: AuthorizedHttp(
          accessToken: () => 't', renewSession: () async => false),
    );

Map<String, Object?> _invitation(String id, String status) => {
      'id': id,
      'status': status,
      'technician': {'displayName': 'Carlos G.'},
      'createdAt': '2026-11-10T15:00:00Z',
      'expiresAt': '2026-11-17T15:00:00Z',
      'respondedAt': null,
    };

void main() {
  const path = '/api/users/companies/me/invitations';

  test('invita por correo limpio', () async {
    late http.Request asked;
    final repo = _repo((r) async {
      asked = r;
      return _json(201, _invitation('i1', 'PENDING'));
    });

    final invitation = await repo.invite('  tecnico5@fixia-qa.test ');

    expect(asked.method, 'POST');
    expect(asked.url.path, path);
    expect(asked.headers['Authorization'], 'Bearer t');
    expect(
        jsonDecode(asked.body), {'technicianEmail': 'tecnico5@fixia-qa.test'});
    expect(invitation.status, InvitationStatus.pending);
    expect(invitation.technicianName, 'Carlos G.');
    expect(invitation.cancellable, isTrue);
  });

  test('un correo inválido no llega al backend', () async {
    var calls = 0;
    final repo = _repo((_) async {
      calls++;
      return _json(201, _invitation('i1', 'PENDING'));
    });
    for (final email in ['', '  ', 'sin-arroba', 'a@b']) {
      await expectLater(repo.invite(email), throwsA(isA<InvitationFailure>()));
    }
    expect(calls, 0);
  });

  test('422 no revela por qué no se puede invitar', () {
    final repo = _repo((_) async => _json(422, {
          'title': 'Invitación no permitida',
          'detail': 'No es posible invitar a esa cuenta',
          'reasons': ['NOT_INVITABLE'],
        }));
    expect(
      () => repo.invite('x@fixia.co'),
      throwsA(isA<InvitationFailure>().having((f) => f.message, 'message',
          HttpCompanyInvitationsRepository.notInvitableMessage)),
    );
  });

  test('409 al invitar: ya hay una pendiente', () {
    final repo = _repo((_) async => _json(409, {'title': 'conflicto'}));
    expect(
      () => repo.invite('x@fixia.co'),
      throwsA(isA<InvitationFailure>().having((f) => f.message, 'message',
          HttpCompanyInvitationsRepository.alreadyPendingMessage)),
    );
  });

  test('lista con filtro y descarta lo inválido', () async {
    late Uri url;
    final repo = _repo((r) async {
      url = r.url;
      return _json(200, {
        'invitations': [
          _invitation('i1', 'EXPIRED'),
          {
            ..._invitation('i2', 'ACCEPTED'),
            'respondedAt': '2026-11-11T10:00:00Z'
          },
          {'id': 'rota'},
        ],
      });
    });

    final items = await repo.list(status: InvitationStatus.expired);

    expect(url.path, path);
    expect(url.queryParameters, {'status': 'EXPIRED'});
    expect(items.map((i) => i.id), ['i1', 'i2']);
    expect(items.first.cancellable, isFalse);
    expect(items.last.respondedAt, DateTime.utc(2026, 11, 11, 10));
  });

  test('sin filtro no manda status', () async {
    late Uri url;
    final repo = _repo((r) async {
      url = r.url;
      return _json(200, {'invitations': []});
    });
    expect(await repo.list(), isEmpty);
    expect(url.hasQuery, isFalse);
  });

  test('cancela con DELETE', () async {
    late http.Request asked;
    final repo = _repo((r) async {
      asked = r;
      return http.Response('', 204);
    });
    await repo.cancel('i1');
    expect(asked.method, 'DELETE');
    expect(asked.url.path, '$path/i1');
  });

  test('cancelar una que ya no está pendiente (409) o no existe (404)',
      () async {
    await expectLater(
      _repo((_) async => _json(409, {})).cancel('i1'),
      throwsA(isA<InvitationFailure>().having((f) => f.message, 'message',
          HttpCompanyInvitationsRepository.notPendingMessage)),
    );
    await expectLater(
      _repo((_) async => _json(404, {})).cancel('i1'),
      throwsA(isA<InvitationFailure>().having((f) => f.message, 'message',
          HttpCompanyInvitationsRepository.notFoundMessage)),
    );
  });

  test('errores comunes', () async {
    await expectLater(
      _repo((_) async => _json(403, {})).list(),
      throwsA(isA<InvitationFailure>().having((f) => f.message, 'message',
          HttpCompanyInvitationsRepository.forbiddenMessage)),
    );
    await expectLater(
      _repo((_) async => throw http.ClientException('caído')).list(),
      throwsA(isA<InvitationFailure>().having((f) => f.message, 'message',
          HttpCompanyInvitationsRepository.connectionErrorMessage)),
    );
    await expectLater(
      _repo((_) async => _json(500, {})).list(),
      throwsA(isA<InvitationFailure>().having((f) => f.message, 'message',
          HttpCompanyInvitationsRepository.unavailableMessage)),
    );
    await expectLater(
      _repo((_) async => _json(200, {'sin': 'lista'})).list(),
      throwsA(isA<InvitationFailure>()),
    );
  });

  test('sesión vencida', () {
    final repo = _repo((_) async => _json(401, {}));
    expect(
        () => repo.list(),
        throwsA(isA<InvitationFailure>()
            .having((f) => f.isSessionExpired, 'expired', isTrue)));
  });
}
