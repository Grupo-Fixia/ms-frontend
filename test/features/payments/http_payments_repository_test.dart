import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/payments/domain/payments.dart';
import 'package:ms_frontend/features/payments/infrastructure/http_payments_repository.dart';

http.Response _json(int status, Object? body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json'});

HttpPaymentsRepository _repo(MockClientHandler handler) =>
    HttpPaymentsRepository(
      client: MockClient(handler),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
          accessToken: () => 't', renewSession: () async => false),
    );

const _payment = {
  'id': 'p1',
  'serviceRequestId': 'r1',
  'amount': 158700.0,
  'currency': 'COP',
  'failureReason': 'Saldo disponible insuficiente.',
  'breakdown': {
    'price': 138000.0,
    'commission': 20700.0,
    'commissionRate': 0.15,
    'total': 158700.0
  },
  'status': 'Failed',
  'method': 'Wallet',
  'isWalletPayment': true,
  'holdStatus': 'Failed',
  'canRetryHold': true,
};

void main() {
  test('consulta billetera y movimientos', () async {
    final asked = <Uri>[];
    final repo = _repo((r) async {
      asked.add(r.url);
      if (r.url.path.endsWith('/entries')) {
        return _json(200, {
          'items': [
            {
              'id': 'e1',
              'type': 'TopUp',
              'amount': 200000,
              'availableAfter': 200000.5,
              'heldAfter': 0,
              'reference': 'TOPUP-1',
              'createdAt': '2026-11-03T03:43:15Z'
            },
            {'id': 'e2', 'type': 'Desconocido', 'amount': 1, 'createdAt': 'x'},
          ],
          'nextCursor': 'c2',
        });
      }
      return _json(200,
          {'availableBalance': 1500.25, 'heldBalance': 0, 'currency': 'COP'});
    });
    final wallet = await repo.wallet();
    expect(wallet.availableCents, 150025);
    expect(wallet.heldCents, 0);
    final page = await repo.entries(cursor: 'c1');
    expect(asked.last.path, '/api/payments/wallets/me/entries');
    expect(asked.last.queryParameters, {'limit': '20', 'cursor': 'c1'});
    expect(page.items.single.type, WalletEntryType.topUp);
    expect(page.items.single.availableAfterCents, 20000050);
    expect(page.nextCursor, 'c2');
  });

  test('recarga y retiro envían monto en pesos e Idempotency-Key', () async {
    final requests = <http.Request>[];
    final repo = _repo((r) async {
      requests.add(r);
      return _json(201,
          {'availableBalance': 250000.5, 'heldBalance': 0, 'currency': 'COP'});
    });
    final wallet = await repo.topUp(25000050);
    await repo.withdraw(1000000);
    expect(wallet.availableCents, 25000050);
    expect(requests[0].url.path, '/api/payments/wallets/me/top-ups');
    expect(jsonDecode(requests[0].body), {'amount': 250000.5});
    expect(requests[1].url.path, '/api/payments/wallets/me/withdrawals');
    expect(jsonDecode(requests[1].body), {'amount': 10000});
    final keys = requests.map((r) => r.headers['Idempotency-Key']).toSet();
    expect(keys, hasLength(2));
    expect(keys.first, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('cotiza la comisión y lee el pago de un servicio', () async {
    final repo = _repo((r) async {
      if (r.url.path.endsWith('commission-quote')) {
        expect(r.url.queryParameters['amount'], '138000');
        return _json(200, {
          'price': 138000,
          'commission': 20700.0,
          'total': 158700.0,
          'currency': 'COP',
          'rate': 0.15,
          'ruleId': 'rule-1',
          'ruleValidFrom': '2026-01-01T00:00:00Z'
        });
      }
      if (r.url.path.endsWith('/process')) {
        return _json(200, {
          ..._payment,
          'holdStatus': 'Held',
          'status': 'Processing',
          'canRetryHold': false
        });
      }
      if (r.url.path.endsWith('/r404')) return _json(404, {});
      return _json(200, _payment);
    });
    final quote = await repo.commissionQuote(13800000);
    expect(quote.totalCents, 15870000);
    expect(quote.ratePercent, '15 %');
    final payment = await repo.paymentForRequest('r1');
    expect(payment!.holdStatus, HoldStatus.failed);
    expect(payment.canRetryHold, isTrue);
    expect(payment.commissionCents, 2070000);
    expect(payment.failureReason, 'Saldo disponible insuficiente.');
    expect(await repo.paymentForRequest('r404'), isNull);
    final retried = await repo.retryHold('p1');
    expect(retried.holdStatus, HoldStatus.held);
  });

  test('errores: detalle del servidor, permisos, caída y sesión', () async {
    Future<Object?> fail(http.Response response) async {
      try {
        await _repo((_) async => response).wallet();
        return null;
      } catch (e) {
        return e;
      }
    }

    expect('${await fail(_json(409, {'detail': 'Saldo insuficiente'}))}',
        'Saldo insuficiente');
    expect('${await fail(_json(403, {}))}',
        HttpPaymentsRepository.forbiddenMessage);
    expect('${await fail(_json(500, {}))}',
        HttpPaymentsRepository.unavailableMessage);
    expect('${await fail(http.Response('x', 200))}',
        HttpPaymentsRepository.unavailableMessage);
    final expired = await fail(_json(401, {})) as PaymentsFailure;
    expect(expired.isSessionExpired, isTrue);
    final offline = HttpPaymentsRepository(
      client: MockClient((_) async => throw http.ClientException('x')),
      baseUrl: Uri.parse('http://localhost'),
      authorizedHttp: AuthorizedHttp(
          accessToken: () => 't', renewSession: () async => false),
    );
    await expectLater(offline.wallet(), throwsA(isA<PaymentsFailure>()));
  });

  test('utilidades de pagos', () {
    expect(pesosToCents(158700.5), 15870050);
    expect(newIdempotencyKey(Random(1)),
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4')));
    expect(HoldStatus.fromApi('Raro'), HoldStatus.unknown);
    expect(WalletEntryType.fromApi('Capture')!.sign, 0);
    expect(
        const CommissionQuote(
                priceCents: 0, commissionCents: 0, totalCents: 0, rate: 0.125)
            .ratePercent,
        '12.5 %');
  });
}
