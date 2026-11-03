import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/payments/domain/payment.dart';
import 'package:ms_frontend/features/payments/infrastructure/http_payment_repository.dart';

Map<String, dynamic> paymentJson(
        {String status = 'Failed', String method = 'Wallet'}) =>
    {
      'id': 'pay-1',
      'serviceRequestId': 'req-1',
      'amount': 1150.5,
      'currency': 'COP',
      'status': status,
      'method': method,
      'failureReason': null,
    };
Map<String, dynamic> walletPaymentJson(
        {String status = 'Failed', bool payer = true}) =>
    {
      ...paymentJson(status: status),
      'isWalletPayment': true,
      'breakdown': {
        'price': 1000.5,
        'commission': 150,
        'commissionRate': 0.149925,
        'total': 1150.5
      },
      'holdStatus': {
        'Pending': 'Pending',
        'Processing': 'Held',
        'Failed': 'Failed',
        'Completed': 'Captured',
        'Refunded': 'Released'
      }[status],
      'canRetryHold': status == 'Failed' && payer,
    };
Map<String, dynamic> quoteJson() => {
      'price': 1000.5,
      'commission': 150,
      'total': 1150.5,
      'currency': 'COP',
      'rate': 0.15,
      'ruleId': 'rule-1',
      'ruleValidFrom': '2026-11-02T00:00:00Z',
    };
http.Response response(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
HttpPaymentRepository repository(MockClientHandler handler,
        {AuthorizedHttp? auth}) =>
    HttpPaymentRepository(
        client: MockClient(handler),
        baseUrl: Uri.parse('http://gateway'),
        authorizedHttp: auth ??
            AuthorizedHttp(
                accessToken: () => 'token', renewSession: () async => false));

void main() {
  for (final entry in [
    ('Pending', 'Pending', HoldStatus.pending, 'Retención pendiente'),
    ('Processing', 'Held', HoldStatus.held, 'Pago retenido'),
    ('Failed', 'Failed', HoldStatus.failed, 'Retención fallida'),
    ('Completed', 'Captured', HoldStatus.captured, 'Retención cobrada'),
    ('Refunded', 'Released', HoldStatus.released, 'Retención liberada'),
    ('Refunded', 'Reversed', HoldStatus.reversed, 'Pago revertido'),
  ]) {
    test('contrato explícito ${entry.$2} conserva su significado', () {
      final p = ServicePayment.fromJson({
        ...walletPaymentJson(status: entry.$1),
        'holdStatus': entry.$2,
      });
      expect(p.isWalletPayment, isTrue);
      expect(p.confirmedHoldStatus, entry.$3);
      expect(p.confirmedHoldStatus.label, entry.$4);
      expect(p.canRetryHold, entry.$1 == 'Failed');
      expect(p.breakdown!.priceCents, 100050);
      expect(p.breakdown!.commissionCents, 15000);
      expect(p.breakdown!.totalCents, 115050);
      expect(p.breakdown!.commissionRate, 0.149925);
    });
  }
  test(
      'Wallet heredado explícitamente no aplicable nunca se considera retenido',
      () {
    final p = ServicePayment.fromJson({
      ...paymentJson(status: 'Processing'),
      'isWalletPayment': false,
      'holdStatus': 'NotApplicable',
      'canRetryHold': false,
      'breakdown': null,
    });
    expect(p.isWalletPayment, isFalse);
    expect(p.confirmedHoldStatus, HoldStatus.notApplicable);
    expect(p.confirmedHoldStatus.label, 'Retención no aplicable');
    expect(p.canRetryHold, isFalse);
    expect(p.breakdown, isNull);
  });
  test('el discriminador explícito no se deduce del método', () {
    final p = ServicePayment.fromJson({
      ...walletPaymentJson(status: 'Processing'),
      'method': 'OtroMetodo',
    });
    expect(p.isWalletPayment, isTrue);
    expect(p.confirmedHoldStatus, HoldStatus.held);
  });
  for (final patch in <Map<String, dynamic>>[
    {'isWalletPayment': null, 'breakdown': null},
    {'isWalletPayment': 'true', 'breakdown': null},
    {'canRetryHold': null},
    {'canRetryHold': 'true'},
    {'holdStatus': null},
    {'holdStatus': 'FutureState'},
    {'holdStatus': 'Held'},
    {'status': 'FutureState'},
  ]) {
    test('campos ambiguos o incoherentes bloquean el reintento: $patch', () {
      final p = ServicePayment.fromJson({...walletPaymentJson(), ...patch});
      expect(p.canRetryHold, isFalse);
      expect(p.confirmedHoldStatus == HoldStatus.held, isFalse);
    });
  }
  test('desglose ausente no se reconstruye con una tarifa nueva', () {
    final p =
        ServicePayment.fromJson({...walletPaymentJson(), 'breakdown': null});
    expect(p.breakdown, isNull);
  });
  for (final breakdown in <Object>[
    'invalid',
    {},
    {'price': 1000.5, 'commission': 150, 'commissionRate': 0.15, 'total': 1},
    {
      'price': 1000.5,
      'commission': 150,
      'commissionRate': '0.15',
      'total': 1150.5
    },
    {'price': 1, 'commission': 1, 'commissionRate': 1, 'total': 2},
  ]) {
    test('respuesta con desglose inválido no permite operar: $breakdown',
        () async {
      await expectLater(
          repository((_) async => response({
                ...walletPaymentJson(),
                'breakdown': breakdown,
              })).forRequest('req-1'),
          throwsA(isA<PaymentFailure>()));
    });
  }
  test('cliente autorizado reconsulta y reintenta una vez; devuelve Held',
      () async {
    final calls = <String>[];
    final repo = repository((r) async {
      calls.add('${r.method} ${r.url.path}');
      expect(r.headers['Authorization'], 'Bearer token');
      if (r.method == 'POST') expect(r.body, isEmpty);
      return response(walletPaymentJson(
          status: r.method == 'POST' ? 'Processing' : 'Failed'));
    });
    final result =
        await repo.retryHold(ServicePayment.fromJson(walletPaymentJson()));
    expect(result.confirmedHoldStatus, HoldStatus.held);
    expect(result.canRetryHold, isFalse);
    expect(calls, [
      'GET /api/payments/service-request/req-1',
      'POST /api/payments/pay-1/process'
    ]);
  });
  test(
      'técnico o permiso revocado no envía process aunque la vista anterior lo permitía',
      () async {
    final calls = <String>[];
    final repo = repository((r) async {
      calls.add(r.method);
      return response(walletPaymentJson(payer: false));
    });
    await expectLater(
        repo.retryHold(ServicePayment.fromJson(walletPaymentJson())),
        throwsA(isA<PaymentFailure>()));
    expect(calls, ['GET']);
  });
  test('403 real al procesar no se trata como saldo insuficiente', () async {
    final repo = repository((r) async =>
        r.method == 'GET' ? response(walletPaymentJson()) : response({}, 403));
    await expectLater(
        repo.retryHold(ServicePayment.fromJson(walletPaymentJson())),
        throwsA(isA<PaymentFailure>()
            .having((e) => e.statusCode, 'status', 403)
            .having((e) => e.isInsufficientBalance, 'saldo', isFalse)));
  });
  test('modelos conservan importes y estados del contrato', () {
    final quote = CommissionQuote.fromJson(quoteJson());
    expect(quote.priceCents, 100050);
    expect(quote.commissionCents, 15000);
    expect(quote.totalCents, 115050);
    expect(quote.matches(100050, 'COP'), isTrue);
    expect(quote.matches(100050, 'USD'), isFalse);
    final wallet = WalletBalance.fromJson(
        {'availableBalance': 20.5, 'heldBalance': 500, 'currency': 'COP'});
    expect(wallet.availableCents, 2050);
    expect(wallet.heldCents, 50000);
  });
  for (final value in [-1, 1.001, double.infinity, '100', null]) {
    test('rechaza importe inválido $value',
        () => expect(() => moneyInCents(value), throwsFormatException));
  }
  test('no acepta un desglose inconsistente', () {
    expect(() => CommissionQuote.fromJson({...quoteJson(), 'total': 1}),
        throwsFormatException);
  });
  for (final state in [
    'Pending',
    'Processing',
    'Completed',
    'Failed',
    'Refunded',
    'NewStatus'
  ]) {
    test('mapea $state sin confundir retenido y completado', () {
      final p = ServicePayment.fromJson(paymentJson(status: state));
      final expected = {
        'Pending': (PaymentStatus.pending, 'Pago pendiente'),
        'Processing': (PaymentStatus.processing, 'Pago en procesamiento'),
        'Completed': (PaymentStatus.completed, 'Pago completado'),
        'Failed': (PaymentStatus.failed, 'Pago fallido'),
        'Refunded': (PaymentStatus.refunded, 'Pago reembolsado'),
        'NewStatus': (PaymentStatus.unknown, 'Estado del pago no reconocido'),
      }[state]!;
      expect(p.status, expected.$1);
      expect(p.label, expected.$2);
      expect(p.canRetryHold, isFalse);
      expect(p.label == 'Pago completado', state == 'Completed');
      expect(p.label == 'Pago retenido', isFalse);
    });
  }
  test('un procesamiento de otro método no se anuncia retenido', () {
    final p = ServicePayment.fromJson(
        paymentJson(status: 'Processing', method: 'CreditCard'));
    expect(p.label, 'Pago en procesamiento');
    expect(p.canRetryHold, isFalse);
  });
  test('consulta comisión con decimal exacto, moneda y Bearer', () async {
    final repo = repository((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/payments/commission-quote');
      expect(r.url.queryParameters, {'amount': '1000.50', 'currency': 'COP'});
      expect(r.headers['Authorization'], 'Bearer token');
      return response(quoteJson());
    });
    expect((await repo.quote(100050, 'COP')).totalCents, 115050);
  });
  test('rechaza comisión para otro precio o moneda', () async {
    await expectLater(
        repository((_) async => response(quoteJson())).quote(100000, 'COP'),
        throwsA(isA<PaymentFailure>()));
    await expectLater(
        repository((_) async => response(quoteJson())).quote(100050, 'USD'),
        throwsA(isA<PaymentFailure>()));
  });
  test('consulta pago y saldo global en rutas separadas', () async {
    final paths = <String>[];
    final repo = repository((r) async {
      paths.add(r.url.path);
      return response(r.url.path.endsWith('/me')
          ? {'availableBalance': 2000, 'heldBalance': 4000, 'currency': 'COP'}
          : paymentJson());
    });
    expect((await repo.forRequest('req-1'))!.amountCents, 115050);
    expect((await repo.wallet()).heldCents, 400000);
    expect(paths,
        ['/api/payments/service-request/req-1', '/api/payments/wallets/me']);
  });
  test('404 de consulta es no disponible; no inventa pago', () async {
    expect(await repository((_) async => response({}, 404)).forRequest('req-1'),
        isNull);
  });
  test('rechaza un pago de otra solicitud', () async {
    await expectLater(
        repository((_) async => response(paymentJson())).forRequest('req-2'),
        throwsA(isA<PaymentFailure>()));
  });
  test('Wallet fallido sin discriminador no envía process', () async {
    final calls = <String>[];
    final repo = repository((r) async {
      calls.add('${r.method} ${r.url.path}');
      if (r.method == 'POST') expect(r.body, isEmpty);
      return response(
          paymentJson(status: r.method == 'POST' ? 'Processing' : 'Failed'));
    });
    await expectLater(repo.retryHold(ServicePayment.fromJson(paymentJson())),
        throwsA(isA<PaymentFailure>()));
    expect(calls, ['GET /api/payments/service-request/req-1']);
  });
  for (final status in [
    'Pending',
    'Processing',
    'Completed',
    'Refunded',
    'NewState'
  ]) {
    test('no procesa si el estado actual es $status', () async {
      final repo = repository((r) async {
        expect(r.method, 'GET');
        return response(paymentJson(status: status));
      });
      await expectLater(repo.retryHold(ServicePayment.fromJson(paymentJson())),
          throwsA(isA<PaymentFailure>()));
    });
  }
  test('no procesa un método heredado fallido', () async {
    final repo = repository((r) async {
      expect(r.method, 'GET');
      return response(paymentJson(method: 'CreditCard'));
    });
    await expectLater(repo.retryHold(ServicePayment.fromJson(paymentJson())),
        throwsA(isA<PaymentFailure>()));
  });
  for (final title in [
    'Saldo insuficiente',
    'Modificación concurrente',
    'Sin tarifa de comisión vigente'
  ]) {
    test('409 distingue $title', () async {
      await expectLater(
          repository((_) async =>
              response({'title': title, 'detail': 'detalle'}, 409)).wallet(),
          throwsA(isA<PaymentFailure>()
              .having((f) => f.isInsufficientBalance, 'saldo insuficiente',
                  title == 'Saldo insuficiente')
              .having((f) => f.message, 'detalle', 'detalle')));
    });
  }
  for (final status in [400, 403, 404, 500]) {
    test('error HTTP $status no produce saldo', () async {
      await expectLater(repository((_) async => response({}, status)).wallet(),
          throwsA(isA<PaymentFailure>()));
    });
  }
  test('sesión expirada se propaga al mecanismo existente', () async {
    await expectLater(
        repository((_) async => response({}, 401)).wallet(),
        throwsA(isA<PaymentFailure>()
            .having((e) => e.isSessionExpired, 'sesión', isTrue)));
  });
  test('401 tras renovar no declara expirada una sesión renovada', () async {
    var token = 'old';
    var renewals = 0;
    await expectLater(
        repository((_) async => response({}, 401),
            auth: AuthorizedHttp(
                accessToken: () => token,
                renewSession: () async {
                  renewals++;
                  token = 'new';
                  return true;
                })).wallet(),
        throwsA(isA<PaymentFailure>()
            .having((e) => e.isSessionExpired, 'sesión', isFalse)));
    expect(renewals, 1);
  });
  test('timeout se informa sin reenvío automático', () async {
    var calls = 0;
    await expectLater(
        repository((_) {
          calls++;
          return Completer<http.Response>().future;
        },
                auth: AuthorizedHttp(
                    accessToken: () => 'token',
                    renewSession: () async => false,
                    timeout: const Duration(milliseconds: 1)))
            .wallet(),
        throwsA(isA<PaymentFailure>()));
    expect(calls, 1);
  });
  test('JSON malformado no se muestra como éxito', () async {
    await expectLater(
        repository((_) async => http.Response('invalid', 200)).wallet(),
        throwsA(isA<PaymentFailure>()));
  });
}
