import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/request_progress_sections.dart';
import 'package:ms_frontend/features/payments/domain/payments.dart';
import 'package:ms_frontend/features/payments/presentation/service_payment_panel.dart';
import '../service_flow_fakes.dart';
import 'payment_repository_test.dart' show walletPaymentJson;

CommissionQuote quote(int cents, String currency) => CommissionQuote(
    priceCents: cents,
    commissionCents: 15000,
    totalCents: cents + 15000,
    rate: .15,
    currency: currency);
ServicePayment payment(PaymentStatus status,
        {String method = 'Wallet',
        bool isWalletPayment = true,
        HoldStatus holdStatus = HoldStatus.unknown,
        bool canRetryHold = false}) =>
    ServicePayment(
        id: 'pay-1',
        serviceRequestId: 'req-1',
        amountCents: 115000,
        currency: 'COP',
        status: status,
        method: method,
        isWalletPayment: isWalletPayment,
        holdStatus: holdStatus,
        canRetryHold: canRetryHold);

ServicePayment retryablePayment() => payment(PaymentStatus.failed,
    holdStatus: HoldStatus.failed, canRetryHold: true);

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
  await tester.pumpAndSettle();
}

Widget quotations(FakeQuotations q,
        {Future<CommissionQuote> Function(int, String)? load}) =>
    ClientQuotationSection(
        load: () => q.listForRequest('req-1'),
        loadCommission: load,
        accept: (id) => q.accept('req-1', id),
        reject: (id) => q.reject('req-1', id),
        onChanged: () async {});
Widget panel(
        {required Future<ServicePayment?> Function() load,
        Future<ServicePayment> Function(String)? retry,
        bool closed = false,
        Future<Wallet> Function()? wallet,
        Future<void> Function()? topUp}) =>
    ServicePaymentPanel(
        load: load,
        isClient: true,
        serviceClosed: closed,
        retryHold: retry ?? (_) async => throw StateError('No debe procesar'),
        loadWallet: wallet ??
            () async => const Wallet(
                availableCents: 100, heldCents: 500000, currency: 'COP'),
        openTopUp: topUp);

void main() {
  for (final payer in [true, false]) {
    testWidgets('permiso de reintento del cliente/técnico: pagador=$payer',
        (t) async {
      var reads = 0;
      var retries = 0;
      await pump(
          t,
          panel(load: () async {
            reads++;
            return ServicePayment.fromJson(walletPaymentJson(
                payer: payer, status: retries == 0 ? 'Failed' : 'Processing'));
          }, retry: (_) async {
            retries++;
            return ServicePayment.fromJson(
                walletPaymentJson(status: 'Processing'));
          }));
      expect(find.text('Retención fallida'), findsOneWidget);
      expect(find.text('Precio del prestador'), findsOneWidget);
      expect(find.text('1.000,50 COP'), findsOneWidget);
      expect(find.textContaining('Comisión de Fixia'), findsOneWidget);
      expect(find.text('150 COP'), findsOneWidget);
      expect(find.text('Total del cliente'), findsOneWidget);
      expect(find.text('1.150,50 COP'), findsOneWidget);
      expect(find.text('Recargar saldo'), findsNothing);
      expect(find.text('Reintentar retención'),
          payer ? findsOneWidget : findsNothing);
      if (payer) {
        await t.tap(find.text('Reintentar retención'));
        await t.pumpAndSettle();
        expect(retries, 1);
        expect(reads, 2);
        expect(find.text('Pago retenido'), findsOneWidget);
        expect(find.text('Pago completado'), findsNothing);
      } else {
        expect(retries, 0);
      }
    });
  }
  for (final entry in [
    ('Pending', 'Pending', 'Retención pendiente'),
    ('Processing', 'Held', 'Pago retenido'),
    ('Completed', 'Captured', 'Retención cobrada'),
    ('Refunded', 'Released', 'Retención liberada'),
    ('Refunded', 'Reversed', 'Pago revertido'),
  ]) {
    testWidgets('presenta ${entry.$2} sin confundirlo con otros estados',
        (t) async {
      await pump(
          t,
          panel(
              load: () async => ServicePayment.fromJson({
                    ...walletPaymentJson(status: entry.$1),
                    'holdStatus': entry.$2,
                  })));
      expect(find.text(entry.$3), findsOneWidget);
      expect(find.text('Pago completado'),
          entry.$1 == 'Completed' ? findsOneWidget : findsNothing);
      expect(find.text('Pago retenido'),
          entry.$2 == 'Held' ? findsOneWidget : findsNothing);
      expect(find.text('Reintentar retención'), findsNothing);
    });
  }
  testWidgets('la navegación inyectada a recarga no depende de canRetryHold',
      (t) async {
    var visits = 0;
    await pump(
        t,
        panel(
          load: () async =>
              ServicePayment.fromJson(walletPaymentJson(payer: false)),
          topUp: () async {
            visits++;
          },
        ));
    expect(find.text('Reintentar retención'), findsNothing);
    await t.tap(find.text('Recargar saldo'));
    await t.pumpAndSettle();
    expect(visits, 1);
  });
  testWidgets('Wallet ambiguo nunca ofrece ni ejecuta reintento', (t) async {
    var attempts = 0;
    await pump(
        t,
        panel(
          load: () async => payment(PaymentStatus.failed),
          retry: (p) async {
            attempts++;
            return payment(PaymentStatus.failed);
          },
        ));
    expect(find.text('Reintentar retención'), findsNothing);
    expect(find.text('Recargar saldo'), findsNothing);
    expect(
        find.text(
            'El reintento de retención no está disponible para este pago.'),
        findsOneWidget);
    await t.tap(find.text('Actualizar pago'));
    await t.pumpAndSettle();
    expect(attempts, 0);
  });

  testWidgets('dos pulsaciones de actualizar comparten una consulta',
      (t) async {
    var reads = 0;
    final pending = Completer<ServicePayment?>();
    await pump(t, panel(load: () {
      reads++;
      return reads == 1
          ? Future.value(payment(PaymentStatus.pending))
          : pending.future;
    }));
    final press = t
        .widget<TextButton>(find.widgetWithText(TextButton, 'Actualizar pago'))
        .onPressed!;
    press();
    press();
    await t.pump();
    expect(reads, 2);
    expect(
        t
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Actualizar pago'))
            .onPressed,
        isNull);
    pending.complete(payment(PaymentStatus.completed));
    await t.pumpAndSettle();
    expect(find.text('Pago completado'), findsOneWidget);
  });

  for (final oldFirst in [false, true]) {
    testWidgets('cierre invalida consulta previa, antigua primero=$oldFirst',
        (t) async {
      final old = Completer<ServicePayment?>();
      final latest = Completer<ServicePayment?>();
      var reads = 0;
      Future<ServicePayment?> load() {
        reads++;
        return reads == 1 ? old.future : latest.future;
      }

      Widget screen(bool closed) => MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: panel(load: load, closed: closed))));
      await t.pumpWidget(screen(false));
      await t.pump();
      await t.pumpWidget(screen(true));
      await t.pump();
      expect(reads, 2);
      if (oldFirst) {
        old.complete(payment(PaymentStatus.failed));
        await t.pump();
        expect(find.text('Pago fallido'), findsNothing);
        expect(
            t
                .widget<TextButton>(
                    find.widgetWithText(TextButton, 'Actualizar pago'))
                .onPressed,
            isNull);
      }
      latest.complete(payment(PaymentStatus.completed));
      await t.pumpAndSettle();
      expect(find.text('Servicio cerrado.'), findsOneWidget);
      expect(find.text('Pago completado'), findsOneWidget);
      if (!oldFirst) {
        old.complete(payment(PaymentStatus.processing));
        await t.pumpAndSettle();
        expect(find.text('Pago en procesamiento'), findsNothing);
      }
      expect(find.text('Pago completado'), findsOneWidget);
      expect(
          t
              .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Actualizar pago'))
              .onPressed,
          isNotNull);
    });
  }
  for (final width in [390.0, 834.0, 1440.0]) {
    testWidgets('pago y desglose sin desbordamiento a ${width}px', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
        body: SingleChildScrollView(
            child: panel(
          load: () async => payment(PaymentStatus.failed),
        )),
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final q = FakeQuotations()..add('req-1', 100000);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
        body: SingleChildScrollView(
            child:
                quotations(q, load: (c, currency) async => quote(c, currency))),
      )));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Aceptar'));
      await t.tap(find.text('Aceptar'));
      await t.pumpAndSettle();
      expect(find.text('Total del cliente'), findsOneWidget);
      expect(find.text('1.150 COP'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('aceptación bloqueada sin integración de comisión', (t) async {
    final q = FakeQuotations()..add('req-1', 100000);
    await pump(t, quotations(q));
    await t.tap(find.text('Aceptar'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Aceptar y contratar'))
            .onPressed,
        isNull);
    expect(q.items.single.isCurrent, isTrue);
  });
  testWidgets('espera comisión, muestra desglose y contrata una sola vez',
      (t) async {
    final contracts = FakeContracts();
    final q = FakeQuotations(contracts: contracts)..add('req-1', 100000);
    final pending = Completer<CommissionQuote>();
    await pump(
        t,
        quotations(q, load: (cents, currency) {
          expect(cents, 100000);
          expect(currency, 'COP');
          return pending.future;
        }));
    await t.tap(find.text('Aceptar'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Aceptar y contratar'))
            .onPressed,
        isNull);
    pending.complete(quote(100000, 'COP'));
    await t.pumpAndSettle();
    expect(find.textContaining('Comisión de Fixia'), findsOneWidget);
    expect(find.text('Total del cliente'), findsOneWidget);
    expect(find.text('1.150 COP'), findsOneWidget);
    await t.tap(find.text('Aceptar y contratar'));
    await t.pumpAndSettle();
    expect(contracts.items, hasLength(1));
  });
  testWidgets('comisión ajena no habilita aceptación', (t) async {
    final q = FakeQuotations()..add('req-1', 100000);
    await pump(t, quotations(q, load: (_, __) async => quote(200000, 'COP')));
    await t.tap(find.text('Aceptar'));
    await t.pumpAndSettle();
    expect(find.text('El desglose no corresponde a esta cotización.'),
        findsOneWidget);
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Aceptar y contratar'))
            .onPressed,
        isNull);
  });
  testWidgets('error de comisión permite consultar otra vez', (t) async {
    var calls = 0;
    final q = FakeQuotations()..add('req-1', 100000);
    await pump(
        t,
        quotations(q, load: (c, currency) async {
          if (calls++ == 0) throw const PaymentsFailure('Sin tarifa vigente');
          return quote(c, currency);
        }));
    await t.tap(find.text('Aceptar'));
    await t.pumpAndSettle();
    expect(find.text('Sin tarifa vigente'), findsOneWidget);
    await t.tap(find.text('Reintentar desglose'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Aceptar y contratar'))
            .onPressed,
        isNotNull);
  });
  testWidgets('cotización reemplazada durante el diálogo no se acepta',
      (t) async {
    final contracts = FakeContracts();
    final q = FakeQuotations(contracts: contracts)..add('req-1', 100000);
    await pump(
        t, quotations(q, load: (c, currency) async => quote(c, currency)));
    await t.tap(find.text('Aceptar'));
    await t.pumpAndSettle();
    q.items.clear();
    q.add('req-1', 200000);
    await t.tap(find.text('Aceptar y contratar'));
    await t.pumpAndSettle();
    expect(contracts.items, isEmpty);
    expect(
        find.text(
            'La cotización cambió. Revisa la versión vigente y su desglose.'),
        findsOneWidget);
  });
  testWidgets('rechazo no depende de pagos', (t) async {
    final q = FakeQuotations()..add('req-1', 100000);
    await pump(t, quotations(q));
    await t.tap(find.text('Rechazar'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Rechazar'));
    await t.pumpAndSettle();
    expect(q.items.single.isCurrent, isFalse);
  });
  const labels = {
    PaymentStatus.pending: 'Pago pendiente',
    PaymentStatus.processing: 'Pago en procesamiento',
    PaymentStatus.completed: 'Pago completado',
    PaymentStatus.failed: 'Pago fallido',
    PaymentStatus.refunded: 'Pago reembolsado',
    PaymentStatus.unknown: 'Estado del pago no reconocido',
  };
  for (final state in PaymentStatus.values) {
    testWidgets('muestra estado $state sin éxito anticipado', (t) async {
      await pump(t, panel(load: () async => payment(state), closed: true));
      expect(find.text('Servicio cerrado.'), findsOneWidget);
      expect(find.text(labels[state]!), findsOneWidget);
      expect(find.text('Pago completado'),
          state == PaymentStatus.completed ? findsOneWidget : findsNothing);
      expect(find.text('Reintentar retención'), findsNothing);
    });
  }
  testWidgets('404 no se presenta como pago fallido ni completado', (t) async {
    await pump(t, panel(load: () async => null));
    expect(
        find.textContaining('El pago aún no está disponible'), findsOneWidget);
    expect(find.text('Pago fallido'), findsNothing);
    expect(find.text('Pago completado'), findsNothing);
  });
  testWidgets('saldo global separado y recarga ausente no ofrece ruta falsa',
      (t) async {
    await pump(t, panel(load: () async => payment(PaymentStatus.failed)));
    expect(find.text('Total del pago: 1.150 COP'), findsOneWidget);
    expect(find.text('Saldo retenido global: 5.000 COP'), findsOneWidget);
    expect(
        find.text('El saldo disponible es inferior al importe de este pago.'),
        findsOneWidget);
    expect(find.text('Recargar saldo'), findsNothing);
  });
  testWidgets('reintento bloquea doble pulsación y vuelve a consultar',
      (t) async {
    var state = PaymentStatus.failed;
    var attempts = 0;
    final pending = Completer<ServicePayment>();
    await pump(
        t,
        panel(
            load: () async => state == PaymentStatus.failed
                ? retryablePayment()
                : payment(state),
            retry: (_) {
              attempts++;
              return pending.future;
            }));
    final button = find.widgetWithText(OutlinedButton, 'Reintentar retención');
    t.widget<OutlinedButton>(button).onPressed!();
    t.widget<OutlinedButton>(button).onPressed!();
    await t.pump();
    expect(attempts, 1);
    state = PaymentStatus.processing;
    pending.complete(payment(state));
    await t.pumpAndSettle();
    expect(find.text('Pago en procesamiento'), findsOneWidget);
    expect(find.text('Pago retenido'), findsNothing);
    expect(find.text('Pago completado'), findsNothing);
    expect(find.text('Reintentar retención'), findsNothing);
  });
  testWidgets('conflicto no se interpreta como saldo insuficiente', (t) async {
    await pump(
        t,
        panel(
            load: () async => retryablePayment(),
            wallet: () async => const Wallet(
                availableCents: 900000, heldCents: 0, currency: 'COP'),
            retry: (_) async => throw const PaymentsFailure(
                'Modificación concurrente',
                statusCode: 409)));
    await t.tap(find.text('Reintentar retención'));
    await t.pumpAndSettle();
    expect(find.text('Modificación concurrente'), findsOneWidget);
    expect(
        find.text('El saldo disponible es inferior al importe de este pago.'),
        findsNothing);
  });
  testWidgets('error de saldo no borra estado del pago', (t) async {
    await pump(
        t,
        panel(
            load: () async => payment(PaymentStatus.processing),
            wallet: () async => throw const PaymentsFailure('Sin conexión')));
    expect(find.text('Pago en procesamiento'), findsOneWidget);
    expect(find.text('Pago retenido'), findsNothing);
    expect(
        find.textContaining('No pudimos actualizar el saldo'), findsOneWidget);
  });
  testWidgets('destino de recarga inyectado vuelve a consultar al regresar',
      (t) async {
    var reads = 0;
    var visits = 0;
    await pump(
        t,
        panel(load: () async {
          reads++;
          return retryablePayment();
        }, topUp: () async {
          visits++;
        }));
    await t.tap(find.text('Recargar saldo'));
    await t.pumpAndSettle();
    expect(visits, 1);
    expect(reads, 2);
  });
  testWidgets('respuesta tardía después de salir no actualiza widget destruido',
      (t) async {
    final pending = Completer<ServicePayment?>();
    await t.pumpWidget(MaterialApp(home: panel(load: () => pending.future)));
    await t.pumpWidget(const SizedBox());
    pending.complete(payment(PaymentStatus.completed));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
