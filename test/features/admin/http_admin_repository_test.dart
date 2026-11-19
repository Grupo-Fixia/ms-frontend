import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/admin/domain/admin.dart';
import 'package:ms_frontend/features/admin/infrastructure/http_admin_repository.dart';
import 'package:ms_frontend/features/payments/domain/payments.dart';

http.Response _json(int status, Object? body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json'});

HttpAdminRepository _repo(MockClientHandler handler) => HttpAdminRepository(
      client: MockClient(handler),
      usersBaseUrl: Uri.parse('http://users.local'),
      paymentsBaseUrl: Uri.parse('http://payments.local'),
      authorizedHttp: AuthorizedHttp(
          accessToken: () => 't', renewSession: () async => false),
    );

const _heldPayment = {
  'id': 'p1',
  'serviceRequestId': 'r1',
  'clientId': 'c1',
  'providerId': 'v1',
  'amount': 184000.0,
  'currency': 'COP',
  'status': 'Processing',
  'method': 'Wallet',
  'isWalletPayment': true,
  'holdStatus': 'Held',
  'breakdown': {
    'price': 160000.0,
    'commission': 24000.0,
    'commissionRate': 0.15,
    'total': 184000.0,
  },
  'createdAt': '2026-11-07T15:00:00Z',
  'refundable': true,
  'refundKind': 'RELEASE',
};

void main() {
  group('usuarios', () {
    test('lista con filtros, cursor y token; descarta ítems inválidos',
        () async {
      late http.Request asked;
      final repo = _repo((r) async {
        asked = r;
        return _json(200, {
          'items': [
            {
              'id': 'u1',
              'email': 'tecnico1@fixia-qa.test',
              'firstName': 'Carlos',
              'lastName': 'Giraldo',
              'role': 'PROFESSIONAL',
              'status': 'ACTIVE',
              'createdAt': '2026-11-04T15:00:00Z',
            },
            {'id': 'sin-correo'},
          ],
          'nextCursor': 'abc',
        });
      });

      final page = await repo.users(
        role: AdminUserRole.professional,
        status: AdminUserStatus.active,
        query: 'carlos',
        cursor: 'c0',
      );

      expect(asked.method, 'GET');
      expect(asked.url.host, 'users.local');
      expect(asked.url.path, '/api/users/admin/users');
      expect(asked.url.queryParameters, {
        'role': 'PROFESSIONAL',
        'status': 'ACTIVE',
        'q': 'carlos',
        'limit': '20',
        'cursor': 'c0',
      });
      expect(asked.headers['Authorization'], 'Bearer t');
      expect(page.items, hasLength(1));
      expect(page.items.single.fullName, 'Carlos Giraldo');
      expect(page.items.single.role, AdminUserRole.professional);
      expect(page.nextCursor, 'abc');
    });

    test('sin filtros solo manda el límite; nextCursor nulo es la última',
        () async {
      late Uri url;
      final repo = _repo((r) async {
        url = r.url;
        return _json(200, {'items': [], 'nextCursor': null});
      });
      final page = await repo.users();
      expect(url.queryParameters, {'limit': '20'});
      expect(page.nextCursor, isNull);
    });

    test('detalle con documento enmascarado', () async {
      final repo = _repo((r) async {
        expect(r.url.path, '/api/users/admin/users/u1');
        return _json(200, {
          'id': 'u1',
          'email': 'a@b.co',
          'firstName': 'Ana',
          'lastName': 'Ruiz',
          'role': 'CLIENT',
          'status': 'ACTIVE',
          'phone': '3001234567',
          'documentType': 'CC',
          'documentNumberMasked': '******0001',
        });
      });
      final user = await repo.user('u1');
      expect(user.documentNumberMasked, '******0001');
      expect(user.phone, '3001234567');
    });

    test('404 usa el detail del backend', () async {
      final repo = _repo((_) async =>
          _json(404, {'title': 'No encontrado', 'detail': 'No existe.'}));
      expect(
        () => repo.user('x'),
        throwsA(isA<AdminFailure>()
            .having((f) => f.message, 'message', 'No existe.')
            .having((f) => f.statusCode, 'status', 404)),
      );
    });
  });

  group('pagos', () {
    test('lista con filtro de retención y usuario', () async {
      late Uri url;
      final repo = _repo((r) async {
        url = r.url;
        return _json(200, {
          'items': [
            _heldPayment,
            {..._heldPayment, 'id': 'p2', 'refundable': false, 'refundKind': null},
            {'id': 'roto'},
          ],
          'nextCursor': null,
        });
      });

      final page =
          await repo.payments(holdStatus: HoldStatus.held, userId: ' c1 ');

      expect(url.host, 'payments.local');
      expect(url.path, '/api/payments/admin/payments');
      expect(url.queryParameters,
          {'holdStatus': 'Held', 'userId': 'c1', 'limit': '20'});
      expect(page.items.map((p) => p.id), ['p1', 'p2']);
      final first = page.items.first;
      expect(first.refundable, isTrue);
      expect(first.refundKind, RefundKind.release);
      expect(first.clientId, 'c1');
      expect(first.payment.breakdown!.commissionCents, 2400000);
      expect(page.items.last.refundable, isFalse);
    });

    test('refundable sin tipo conocido no se ofrece', () async {
      final repo = _repo((_) async => _json(200, {
            'items': [
              {..._heldPayment, 'refundKind': 'OTRO'}
            ],
          }));
      final page = await repo.payments();
      expect(page.items.single.refundable, isFalse);
    });

    test('reembolso: POST con motivo e Idempotency-Key', () async {
      late http.Request asked;
      final repo = _repo((r) async {
        asked = r;
        return _json(200, {
          ..._heldPayment,
          'status': 'Refunded',
          'holdStatus': 'Released',
        });
      });

      final result = await repo.refund('p1',
          reason: '  Servicio cancelado  ', idempotencyKey: 'k-1');

      expect(asked.method, 'POST');
      expect(asked.url.path, '/api/payments/p1/refund');
      expect(asked.url.queryParameters, {'reason': 'Servicio cancelado'});
      expect(asked.headers['Idempotency-Key'], 'k-1');
      expect(asked.headers['Authorization'], 'Bearer t');
      expect(result.holdStatus, HoldStatus.released);
    });

    test('reembolso sin motivo no llama al backend', () async {
      var calls = 0;
      final repo = _repo((_) async {
        calls++;
        return _json(200, _heldPayment);
      });
      await expectLater(
          repo.refund('p1', reason: '  ', idempotencyKey: 'k'),
          throwsA(isA<AdminFailure>()));
      await expectLater(
          repo.refund('p1', reason: 'x' * 501, idempotencyKey: 'k'),
          throwsA(isA<AdminFailure>()));
      expect(calls, 0);
    });

    test('409 muestra el motivo del backend', () async {
      final repo = _repo((_) async => _json(409, {
            'title': 'Saldo insuficiente',
            'detail': 'El prestador ya retiró el saldo.',
          }));
      expect(
        () => repo.refund('p1', reason: 'r', idempotencyKey: 'k'),
        throwsA(isA<AdminFailure>()
            .having((f) => f.message, 'message',
                'El prestador ya retiró el saldo.')
            .having((f) => f.statusCode, 'status', 409)),
      );
    });

    test('respuesta de otro pago es un error', () async {
      final repo = _repo((_) async => _json(200, {..._heldPayment, 'id': 'p9'}));
      expect(() => repo.refund('p1', reason: 'r', idempotencyKey: 'k'),
          throwsA(isA<AdminFailure>()));
    });
  });

  group('registro de acciones', () {
    for (final (source, host, path) in [
      (AuditSource.users, 'users.local', '/api/users/admin/audit-events'),
      (AuditSource.payments, 'payments.local',
          '/api/payments/admin/audit-events'),
    ]) {
      test('${source.name}: lee el registro de su servicio', () async {
        late Uri url;
        final repo = _repo((r) async {
          url = r.url;
          return _json(200, {
            'items': [
              {
                'id': 'e1',
                'adminId': 'a1',
                'action': 'PAYMENT_REFUND',
                'targetType': 'PAYMENT',
                'targetId': 'p1',
                'details': {'reason': 'Cancelado', 'kind': 'RELEASE'},
                'outcome': 'OK',
                'occurredAt': '2026-11-07T15:00:00Z',
              }
            ],
            'nextCursor': 'n',
          });
        });
        final page = await repo.auditEvents(source, cursor: 'c');
        expect(url.host, host);
        expect(url.path, path);
        expect(url.queryParameters, {'limit': '20', 'cursor': 'c'});
        final event = page.items.single;
        expect(event.actionLabel, 'Reembolsó un pago');
        expect(event.outcomeLabel, 'Correcto');
        expect(event.details, contains('Cancelado'));
      });
    }
  });

  group('errores comunes', () {
    test('403: la cuenta no es ADMIN', () {
      final repo = _repo((_) async => _json(403, {'title': 'Forbidden'}));
      expect(
          () => repo.users(),
          throwsA(isA<AdminFailure>().having((f) => f.message, 'message',
              HttpAdminRepository.forbiddenMessage)));
    });

    test('sesión vencida avisa para volver al login', () {
      final repo = _repo((_) async => _json(401, {}));
      expect(
          () => repo.payments(),
          throwsA(isA<AdminFailure>()
              .having((f) => f.isSessionExpired, 'expired', isTrue)));
    });

    test('sin red', () {
      final repo = _repo((_) async => throw http.ClientException('caído'));
      expect(
          () => repo.users(),
          throwsA(isA<AdminFailure>().having((f) => f.message, 'message',
              HttpAdminRepository.connectionErrorMessage)));
    });

    test('500 o cuerpo inválido: no disponible', () async {
      for (final response in [
        _json(500, {}),
        http.Response('no json', 200),
        _json(200, {'sin': 'items'}),
      ]) {
        final repo = _repo((_) async => response);
        await expectLater(
            repo.users(),
            throwsA(isA<AdminFailure>().having((f) => f.message, 'message',
                HttpAdminRepository.unavailableMessage)));
      }
    });
  });
}
