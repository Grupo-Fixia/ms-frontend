import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/layout/app_shell.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/payments/domain/payments.dart';
import 'package:ms_frontend/features/payments/presentation/service_payment_panel.dart';
import 'package:ms_frontend/features/payments/presentation/wallet_page.dart';

class _Gateway implements WalletGateway {
  int available = 5000000;
  int held = 0;
  final entries_ = <WalletEntry>[
    WalletEntry(
      id: 'e1',
      type: WalletEntryType.topUp,
      amountCents: 5000000,
      availableAfterCents: 5000000,
      heldAfterCents: 0,
      createdAt: DateTime.utc(2026, 11, 2, 15),
    ),
  ];
  Object? error;
  final ops = <String>[];

  @override
  Future<Wallet> wallet() async {
    if (error != null) throw error!;
    return Wallet(availableCents: available, heldCents: held);
  }

  @override
  Future<WalletEntriesPage> entries({String? cursor}) async {
    if (cursor == null) {
      return WalletEntriesPage(items: entries_, nextCursor: 'c2');
    }
    return WalletEntriesPage(items: [
      WalletEntry(
        id: 'e2',
        type: WalletEntryType.credit,
        amountCents: 13800000,
        availableAfterCents: 18800000,
        heldAfterCents: 0,
        createdAt: DateTime.utc(2026, 11, 1),
      ),
    ]);
  }

  @override
  Future<Wallet> topUp(int amountCents) async {
    ops.add('top $amountCents');
    available += amountCents;
    return wallet();
  }

  @override
  Future<Wallet> withdraw(int amountCents) async {
    ops.add('out $amountCents');
    available -= amountCents;
    return wallet();
  }
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(WidgetTester tester, Widget child,
    {Size size = const Size(1440, 1200)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: FixiaTheme.light, home: child));
  await tester.pumpAndSettle();
}

void main() {
  group('WalletPage', () {
    testWidgets('cliente: saldos, movimientos, más y recarga', (tester) async {
      final gateway = _Gateway();
      await _pump(tester, WalletPage(gateway: gateway, role: ShellRole.client));

      expect(find.text('50.000 COP'), findsWidgets);
      expect(find.text('Recarga'), findsOneWidget);
      expect(_key('wallet-simulated'), findsOneWidget);
      await tester.tap(_key('wallet-more'));
      await tester.pumpAndSettle();
      expect(find.text('Pago recibido por un servicio'), findsOneWidget);
      expect(_key('wallet-more'), findsNothing);

      await tester.tap(_key('wallet-operate'));
      await tester.pumpAndSettle();
      await tester.tap(_key('wallet-amount-confirm'));
      await tester.pump();
      expect(find.textContaining('mayor que cero'), findsOneWidget);
      await tester.tap(_key('wallet-quick-100000'));
      await tester.tap(_key('wallet-amount-confirm'));
      await tester.pumpAndSettle();
      expect(gateway.ops, ['top 10000000']);
      expect(_key('wallet-operation-done'), findsOneWidget);
      expect(find.text('150.000 COP'), findsWidgets);
    });

    testWidgets('técnico: retira y no puede pasar su saldo', (tester) async {
      final gateway = _Gateway();
      await _pump(
          tester, WalletPage(gateway: gateway, role: ShellRole.technician));
      expect(find.text('Retirar saldo'), findsOneWidget);
      await tester.tap(_key('wallet-operate'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('wallet-amount'), '90000');
      await tester.tap(_key('wallet-amount-confirm'));
      await tester.pump();
      expect(find.textContaining('No puedes retirar más'), findsOneWidget);
      await tester.enterText(_key('wallet-amount'), '20000');
      await tester.tap(_key('wallet-amount-confirm'));
      await tester.pumpAndSettle();
      expect(gateway.ops, ['out 2000000']);
    });

    testWidgets('empresa sin movimientos y error con reintento',
        (tester) async {
      final gateway = _Gateway()..error = const PaymentsFailure('Pagos caído');
      await _pump(
          tester, WalletPage(gateway: gateway, role: ShellRole.company));
      expect(find.text('Pagos caído'), findsOneWidget);
      gateway
        ..error = null
        ..entries_.clear();
      await tester.tap(_key('wallet-retry'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Todavía no tienes movimientos'), findsOneWidget);
    });

    testWidgets('sesión vencida avisa', (tester) async {
      var expired = 0;
      final gateway = _Gateway()
        ..error = const PaymentsFailure('x', isSessionExpired: true);
      await _pump(
          tester,
          WalletPage(
              gateway: gateway,
              role: ShellRole.client,
              onSessionExpired: () => expired++));
      expect(expired, 1);
    });

    testWidgets('en celular no desborda', (tester) async {
      await _pump(
          tester, WalletPage(gateway: _Gateway(), role: ShellRole.client),
          size: const Size(360, 900));
      expect(tester.takeException(), isNull);
    });
  });

  group('ServicePaymentPanel', () {
    ServicePayment payment(HoldStatus status, {bool retry = false}) =>
        ServicePayment(
          id: 'p1',
          serviceRequestId: 'r1',
          holdStatus: status,
          canRetryHold: retry,
          priceCents: 13800000,
          commissionCents: 2070000,
          totalCents: 15870000,
          rate: 0.15,
          failureReason:
              status == HoldStatus.failed ? 'Saldo insuficiente' : null,
        );

    Widget host(Widget child) =>
        Scaffold(body: SingleChildScrollView(child: child));

    testWidgets('cliente sin saldo: recarga lo que falta y reintenta',
        (tester) async {
      final gateway = _Gateway()..available = 10000000;
      var retries = 0;
      await _pump(
        tester,
        host(ServicePaymentPanel(
          isClient: true,
          load: () async => payment(HoldStatus.failed, retry: true),
          retryHold: (_) async {
            retries++;
            return payment(HoldStatus.held);
          },
          loadWallet: gateway.wallet,
          topUp: gateway.topUp,
        )),
      );
      expect(find.text('Falta saldo'), findsOneWidget);
      expect(find.text('Saldo insuficiente'), findsOneWidget);
      expect(find.text('Comisión de Fixia (15 %)'), findsOneWidget);

      await tester.tap(_key('service-payment-topup'));
      await tester.pumpAndSettle();
      // Sugiere lo que falta: 158.700 − 100.000.
      expect(find.text('58700'), findsOneWidget);
      await tester.tap(_key('wallet-amount-confirm'));
      await tester.pumpAndSettle();
      expect(gateway.ops, ['top 5870000']);
      expect(retries, 1);
      expect(find.text('Dinero retenido'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
          home: host(ServicePaymentPanel(
              key: UniqueKey(),
              isClient: true,
              load: () async => payment(HoldStatus.failed, retry: true),
              retryHold: (_) async =>
                  throw const PaymentsFailure('Sigue sin saldo')))));
      await tester.pumpAndSettle();
      await tester.tap(_key('service-payment-retry'));
      await tester.pumpAndSettle();
      expect(find.text('Sigue sin saldo'), findsOneWidget);
    });

    testWidgets('mensajes por estado para el técnico y sin pago aún',
        (tester) async {
      for (final (status, text) in [
        (HoldStatus.held, 'Recibirás 138.000 COP'),
        (HoldStatus.captured, 'Recibiste 138.000 COP'),
        (HoldStatus.failed, 'todavía no tiene saldo'),
      ]) {
        await _pump(
            tester,
            host(ServicePaymentPanel(
                key: UniqueKey(),
                isClient: false,
                load: () async => payment(status))));
        expect(find.textContaining(text), findsOneWidget);
        expect(_key('service-payment-retry'), findsNothing);
      }
      var loads = 0;
      await _pump(
          tester,
          host(ServicePaymentPanel(
              key: UniqueKey(),
              isClient: true,
              load: () async {
                loads++;
                if (loads == 1) return null;
                throw const PaymentsFailure('Pagos caído');
              })));
      expect(_key('service-payment-missing'), findsOneWidget);
      await tester.tap(_key('service-payment-reload'));
      await tester.pumpAndSettle();
      expect(find.text('Pagos caído'), findsOneWidget);
    });

    testWidgets('cliente: textos de cobrado, liberado y retenido',
        (tester) async {
      for (final (status, text) in [
        (HoldStatus.captured, 'Pagado: el técnico recibió'),
        (HoldStatus.released, 'volvió a tu saldo'),
        (HoldStatus.held, 'Retuvimos 158.700 COP'),
        (HoldStatus.pending, 'Estamos reteniendo'),
      ]) {
        await _pump(
            tester,
            host(ServicePaymentPanel(
                key: UniqueKey(),
                isClient: true,
                load: () async => payment(status))));
        expect(find.textContaining(text), findsOneWidget);
      }
    });
  });

  group('CommissionPreview', () {
    Future<void> show(WidgetTester tester,
            {int available = 20000000, bool fail = false}) =>
        _pump(
          tester,
          Scaffold(
            body: CommissionPreview(
              priceCents: 13800000,
              quote: (cents) async {
                if (fail) throw const PaymentsFailure('x');
                return CommissionQuote(
                    priceCents: cents,
                    commissionCents: 2070000,
                    totalCents: 15870000,
                    rate: 0.15);
              },
              loadWallet: () async =>
                  Wallet(availableCents: available, heldCents: 0),
            ),
          ),
        );

    testWidgets('desglose y saldo suficiente o insuficiente', (tester) async {
      await show(tester);
      expect(find.text('158.700 COP'), findsOneWidget);
      expect(find.textContaining('alcanza para este servicio'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await show(tester, available: 1000000);
      expect(find.textContaining('no alcanza'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await show(tester, fail: true);
      expect(_key('commission-preview-error'), findsOneWidget);
    });
  });
}
