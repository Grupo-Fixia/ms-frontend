import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/http/authorized_http.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/request_progress_sections.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/contracts/infrastructure/http_contract_repository.dart';
import 'package:ms_frontend/features/contracts/presentation/service_actions.dart';
import 'package:ms_frontend/features/payments/presentation/service_payment_panel.dart';
import 'package:ms_frontend/features/payments/infrastructure/http_payments_repository.dart';
import 'payment_repository_test.dart' show walletPaymentJson, response;

Map<String, Object?> contractJson(String state) => {
      'id': 'contract-1',
      'serviceRequestId': 'req-1',
      'quotationId': 'q-1',
      'clientId': 'client-1',
      'providerId': 'provider-1',
      'amount': 1000.5,
      'currency': 'COP',
      'scope': 'Reparación',
      'conditions': 'Incluye materiales',
      'agreedAt': '2026-11-02T10:00:00Z',
      'contractedAt': '2026-11-01T10:00:00Z',
      'serviceStatus': state,
      'serviceRequest': {
        'category': ServiceCategory.plumbing.apiValue,
        'status': state
      },
    };

void main() {
  for (final lostResponse in [false, true]) {
    testWidgets(
        'cierre único, sin captura directa; respuesta perdida=$lostResponse',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var state = 'TECHNICIAN_FINISHED';
      var paymentState = 'Processing';
      final calls = <String>[];
      final closure = Completer<http.Response>();
      final client = MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        if (r.method == 'POST') {
          if (r.url.path != '/api/services/requests/req-1/closure' ||
              r.body.isNotEmpty) {
            throw StateError('Operación de cierre inesperada');
          }
          state = 'CLOSED';
          return closure.future;
        }
        if (r.url.path.endsWith('/contract')) {
          return response(contractJson(state));
        }
        if (r.url.path.endsWith('/wallets/me')) {
          return response({
            'availableBalance': 0,
            'heldBalance': 1150.5,
            'currency': 'COP'
          });
        }
        return response(walletPaymentJson(status: paymentState));
      });
      final auth = AuthorizedHttp(
          accessToken: () => 'token', renewSession: () async => false);
      final contracts = HttpContractRepository(
          client: client,
          baseUrl: Uri.parse('http://gateway'),
          authorizedHttp: auth);
      final payments = HttpPaymentsRepository(
          client: client,
          baseUrl: Uri.parse('http://gateway'),
          authorizedHttp: auth);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: ClientContractSection(
          load: () => contracts.getForRequest('req-1'),
          walletPayments: true,
          footerBuilder: (contract) => ServicePaymentPanel(
              key: ValueKey(contract.serviceStatus),
              serviceClosed:
                  contract.serviceStatus == ServiceRequestStatus.closed,
              load: () => payments.paymentForRequest('req-1'),
              loadWallet: payments.wallet,
              retryHold: payments.retryHold,
              isClient: true),
          actionsBuilder: (context, contract, reload) => clientServiceActions(
              contract: contract,
              payWithWallet: true,
              confirmClosure: () => contracts.confirmClosure('req-1'),
              object: (reason) => contracts.objectClosure('req-1', reason),
              onDone: reload),
        ),
      ))));
      await tester.pumpAndSettle();
      final action = tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar y pagar'))
          .onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final confirm = tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar y pagar').last)
          .onPressed!;
      confirm();
      confirm();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls.where((c) => c.startsWith('POST')), hasLength(1));
      if (lostResponse) {
        closure.completeError(http.ClientException('respuesta perdida'));
      } else {
        closure.complete(response(contractJson(state)));
      }
      await tester.pumpAndSettle();
      expect(find.text('Confirmar y pagar'), findsNothing);
      // Con el saldo retenido el título dice "Pago retenido", no "en
      // procesamiento" (estado interno de ms-payments).
      expect(find.text('Pago en procesamiento'), findsNothing);
      expect(find.text('Pago retenido'), findsOneWidget);
      expect(find.text('Se cobra cuando se confirme el cierre del servicio.'),
          findsOneWidget);
      expect(
          find.textContaining(
              'El cierre está confirmado, pero el pago no está completado.'),
          findsOneWidget);
      expect(find.text('Pago completado'), findsNothing);
      expect(
          calls
              .where((c) => c == 'GET /api/payments/service-request/req-1')
              .length,
          greaterThanOrEqualTo(2));
      paymentState = 'Completed';
      await tester.tap(find.text('Actualizar pago'));
      await tester.pumpAndSettle();
      expect(find.text('Pago completado'), findsOneWidget);
      expect(find.text('Retención cobrada'), findsOneWidget);
      expect(find.text('Pago retenido'), findsNothing);
      expect(calls.where((c) => c.startsWith('POST')).toList(),
          ['POST /api/services/requests/req-1/closure']);
    });
  }
}
