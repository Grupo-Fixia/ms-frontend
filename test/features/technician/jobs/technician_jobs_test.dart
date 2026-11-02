import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/constants/service_request_status.dart';
import 'package:ms_frontend/features/quotations/domain/quotation.dart';
import 'package:ms_frontend/features/quotations/domain/quotation_exceptions.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';
import 'package:ms_frontend/features/technician/jobs/presentation/technician_contract_page.dart';
import 'package:ms_frontend/features/technician/jobs/presentation/technician_jobs_page.dart';
import 'package:ms_frontend/features/technician/jobs/presentation/technician_quotation_page.dart';

import '../../service_flow_fakes.dart';

ServiceApplication _application(String id, ApplicationStatus status,
        {String requestId = 'req-1'}) =>
    ServiceApplication(
      id: id,
      status: status,
      proposedPrice: ProposedPrice.tryParse('140000'),
      serviceRequest: ApplicationRequestSummary(
        id: requestId,
        category: ServiceCategory.plumbing,
        city: 'Bogotá',
        zone: 'Chapinero',
        status: ServiceRequestStatus.providerSelected,
        expectedAt: DateTime(2030, 1, 10, 9),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  group('TechnicianJobsPage', () {
    testWidgets('separa lo que debe cotizar de lo contratado', (tester) async {
      final quotations = FakeQuotations()..add('req-2', 13800000);
      final contracts = FakeContracts()..contractFrom(quotations.items.single);
      final opened = <String>[];
      await _pump(
        tester,
        TechnicianJobsPage(
          loadApplications: () async => [
            _application('a1', ApplicationStatus.selected),
            _application('a2', ApplicationStatus.selected, requestId: 'req-2'),
            _application('a3', ApplicationStatus.applied, requestId: 'req-3'),
          ],
          loadContracts: contracts.listMine,
          onOpenQuotation: (a) async => opened.add('cotizar ${a.id}'),
          onOpenContract: (c) async => opened.add('contrato ${c.id}'),
          onOpenOpportunities: () => opened.add('oportunidades'),
        ),
      );

      // a2 ya está contratada y a3 no fue seleccionada: solo a1 se cotiza.
      expect(find.byKey(const ValueKey('to-quote-a1')), findsOneWidget);
      expect(find.byKey(const ValueKey('to-quote-a2')), findsNothing);
      expect(find.byKey(const ValueKey('to-quote-a3')), findsNothing);
      expect(find.text('Plomería · 138.000 COP'), findsOneWidget);

      await tester.tap(find.text('Cotizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plomería · 138.000 COP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar oportunidades'));
      expect(opened, ['cotizar a1', 'contrato c1', 'oportunidades']);
    });

    testWidgets('vacío sin datos de ejemplo y error con reintento',
        (tester) async {
      var fail = true;
      await _pump(
        tester,
        TechnicianJobsPage(
          loadApplications: () async {
            if (fail) throw const QuotationFailure('Sin conexión');
            return [];
          },
          loadContracts: () async => [],
          onOpenQuotation: (_) async {},
          onOpenContract: (_) async {},
        ),
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no tienes servicios contratados.'),
          findsOneWidget);
    });
  });

  group('TechnicianQuotationPage', () {
    late FakeQuotations quotations;

    Widget page() => TechnicianQuotationPage(
          application: _application('a1', ApplicationStatus.selected),
          load: () => quotations.listMine(serviceRequestId: 'req-1'),
          send: quotations.send,
          now: () => DateTime(2029, 12, 1, 8),
        );

    setUp(() => quotations = FakeQuotations());

    testWidgets('envía la primera versión y luego un ajuste', (tester) async {
      await _pump(tester, page());
      expect(find.text('Enviar cotización formal'), findsOneWidget);
      expect(find.textContaining('140.000 COP'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('quotation-amount')), '145000');
      await tester.enterText(
          find.byKey(const ValueKey('quotation-scope')), 'Cambio de sifón');
      await tester.enterText(find.byKey(const ValueKey('quotation-conditions')),
          'Incluye materiales');
      await tester.tap(find.text('Enviar cotización'));
      await tester.pumpAndSettle();

      expect(quotations.sends, 1);
      expect(find.text('Versión 1 enviada al cliente.'), findsOneWidget);
      expect(find.text('Versión 1'), findsOneWidget);
      expect(find.text('Vigente'), findsOneWidget);

      await tester.tap(find.text('Ajustar cotización (nueva versión)'));
      await tester.pumpAndSettle();
      // El ajuste parte de la versión vigente.
      expect(find.widgetWithText(TextField, 'Cambio de sifón'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('quotation-amount')), '138000');
      await tester.tap(find.text('Enviar nueva versión'));
      await tester.pumpAndSettle();

      expect(quotations.sends, 2);
      expect(find.text('Versión 2'), findsOneWidget);
      expect(find.text('138.000 COP'), findsOneWidget);
      expect(find.text('Versiones anteriores'), findsOneWidget);
      expect(find.text('Reemplazada'), findsOneWidget);
    });

    testWidgets('valida antes de enviar', (tester) async {
      await _pump(tester, page());
      await tester.tap(find.text('Enviar cotización'));
      await tester.pumpAndSettle();
      expect(quotations.sends, 0);
      expect(find.text('Revisa los datos marcados.'), findsOneWidget);
      expect(find.text('Escribe el valor con máximo dos decimales.'),
          findsOneWidget);
      expect(find.text('Describe el alcance del trabajo.'), findsOneWidget);
    });

    testWidgets('con la cotización aceptada no permite ajustar',
        (tester) async {
      quotations.add('req-1', 13800000, status: QuotationStatus.accepted);
      await _pump(tester, page());
      expect(find.textContaining('El cliente aceptó esta cotización'),
          findsOneWidget);
      expect(find.text('Ajustar cotización (nueva versión)'), findsNothing);
      expect(find.text('Enviar cotización'), findsNothing);
    });

    testWidgets('muestra los errores del backend', (tester) async {
      final failing = TechnicianQuotationPage(
        application: _application('a1', ApplicationStatus.selected),
        load: () async => [],
        send: (_) async => throw const QuotationFailure(
            'Ya no puedes cotizar esta solicitud.'),
        now: () => DateTime(2029, 12, 1, 8),
      );
      await _pump(tester, failing);
      await tester.enterText(
          find.byKey(const ValueKey('quotation-amount')), '145000');
      await tester.enterText(
          find.byKey(const ValueKey('quotation-scope')), 'Cambio de sifón');
      await tester.enterText(find.byKey(const ValueKey('quotation-conditions')),
          'Incluye materiales');
      await tester.tap(find.text('Enviar cotización'));
      await tester.pumpAndSettle();
      expect(find.text('Ya no puedes cotizar esta solicitud.'), findsOneWidget);
    });
  });

  testWidgets('TechnicianContractPage muestra el contrato del servidor',
      (tester) async {
    final quotations = FakeQuotations()..add('req-1', 13800000);
    final contracts = FakeContracts()..contractFrom(quotations.items.single);
    await _pump(
        tester, TechnicianContractPage(load: () => contracts.getMine('c1')));
    expect(find.text('Servicio contratado'), findsOneWidget);
    expect(find.text('138.000 COP'), findsOneWidget);
    expect(find.text('Calle 45 # 13-20'), findsOneWidget);
  });
}
