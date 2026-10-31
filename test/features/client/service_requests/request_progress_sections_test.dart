import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/request_progress_sections.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/quotations/domain/quotation.dart';
import 'package:ms_frontend/features/quotations/domain/quotation_exceptions.dart';
import 'package:ms_frontend/features/quotations/presentation/quotation_card.dart';

import '../../service_flow_fakes.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('formatCents agrupa miles y muestra centavos solo si hay', () {
    expect(formatCents(14500000), '145.000 COP');
    expect(formatCents(14500050), '145.000,50 COP');
    expect(formatCents(100), '1 COP');
  });

  group('ClientQuotationSection', () {
    late FakeContracts contracts;
    late FakeQuotations quotations;
    late int changes;

    Widget section() => ClientQuotationSection(
          load: () => quotations.listForRequest('req-1'),
          accept: (id) => quotations.accept('req-1', id),
          reject: (id) => quotations.reject('req-1', id),
          onChanged: () async => changes++,
        );

    setUp(() {
      contracts = FakeContracts();
      quotations = FakeQuotations(contracts: contracts);
      changes = 0;
    });

    testWidgets('sin cotizaciones espera la del prestador', (tester) async {
      await _pump(tester, section());
      expect(
        find.text('Esperando la cotización formal del prestador seleccionado.'),
        findsOneWidget,
      );
      expect(find.text('Aceptar'), findsNothing);
    });

    testWidgets('muestra la versión vigente y las anteriores', (tester) async {
      quotations
        ..add('req-1', 14500000, status: QuotationStatus.superseded)
        ..add('req-1', 13800000);
      await _pump(tester, section());

      expect(find.text('Versión 2'), findsOneWidget);
      expect(find.text('Vigente'), findsOneWidget);
      expect(find.text('138.000 COP'), findsOneWidget);
      expect(find.text('Versiones anteriores'), findsOneWidget);
      expect(find.text('Versión 1'), findsOneWidget);
      expect(find.text('Reemplazada'), findsOneWidget);
      // Solo la vigente se puede responder.
      expect(find.text('Aceptar'), findsOneWidget);
    });

    testWidgets('aceptar confirma, contrata en el servidor y avisa',
        (tester) async {
      quotations.add('req-1', 13800000);
      await _pump(tester, section());

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('138.000 COP'), findsWidgets);
      await tester.tap(find.text('Aceptar y contratar'));
      await tester.pumpAndSettle();

      expect(quotations.items.single.status, QuotationStatus.accepted);
      expect(contracts.items, hasLength(1));
      expect(changes, 1);
      expect(find.text('Cotización aceptada. El servicio quedó contratado.'),
          findsOneWidget);
      expect(find.text('Aceptada'), findsOneWidget);
      expect(find.text('Aceptar'), findsNothing);
    });

    testWidgets('un error al aceptar no muestra éxito', (tester) async {
      quotations
        ..add('req-1', 13800000)
        ..acceptError = const QuotationFailure(
            'La cotización fue reemplazada por una versión más reciente.');
      await _pump(tester, section());

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar y contratar'));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'La cotización fue reemplazada por una versión más reciente.'),
          findsOneWidget);
      expect(contracts.items, isEmpty);
      expect(find.text('Vigente'), findsOneWidget);
    });

    testWidgets('rechazar deja la cotización rechazada', (tester) async {
      quotations.add('req-1', 13800000);
      await _pump(tester, section());
      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pumpAndSettle();

      expect(quotations.items.single.status, QuotationStatus.rejected);
      expect(find.text('Rechazaste la cotización.'), findsOneWidget);
      expect(
        find.text(
            'No hay una versión vigente. El prestador puede enviarte una nueva.'),
        findsOneWidget,
      );
    });

    testWidgets('volver en la confirmación no responde', (tester) async {
      quotations.add('req-1', 13800000);
      await _pump(tester, section());
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(quotations.items.single.status, QuotationStatus.sent);
      expect(changes, 0);
    });
  });

  group('ClientContractSection', () {
    testWidgets('muestra lo contratado y el historial del servidor',
        (tester) async {
      final quotations = FakeQuotations()..add('req-1', 13800000);
      final contracts = FakeContracts()
        ..contractFrom(quotations.items.single,
            status: ServiceRequestStatus.inProgress);
      await _pump(
        tester,
        ClientContractSection(
          load: () => contracts.getForRequest('req-1'),
          actionsBuilder: (context, contract, reload) =>
              [FilledButton(onPressed: () {}, child: const Text('Acción'))],
        ),
      );

      expect(find.text('Tu contratación'), findsOneWidget);
      expect(find.text('138.000 COP'), findsOneWidget);
      expect(find.text('En ejecución'), findsOneWidget);
      expect(find.text('Calle 45 # 13-20'), findsOneWidget);
      expect(find.textContaining('Contratada (Cliente)'), findsOneWidget);
      expect(find.text('Acción'), findsOneWidget);
    });

    testWidgets('sin contrato muestra el error y permite reintentar',
        (tester) async {
      final contracts = FakeContracts();
      await _pump(tester,
          ClientContractSection(load: () => contracts.getForRequest('req-1')));
      expect(
          find.text('Esta solicitud aún no está contratada.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
