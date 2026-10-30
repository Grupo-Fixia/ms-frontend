import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/request_progress_sections.dart';
import 'package:ms_frontend/features/contracts/domain/contract_exceptions.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/contracts/presentation/service_actions.dart';
import 'package:ms_frontend/features/technician/jobs/presentation/technician_contract_page.dart';

import '../service_flow_fakes.dart';

FakeContracts _contracts(ServiceRequestStatus status) {
  final quotations = FakeQuotations()..add('req-1', 13800000);
  return FakeContracts()..contractFrom(quotations.items.single, status: status);
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

Widget _technician(FakeContracts contracts, {bool withStart = true}) =>
    TechnicianContractPage(
      load: () => contracts.getMine('c1'),
      actionsBuilder: (context, contract, reload) => technicianServiceActions(
        contract: contract,
        start: withStart ? () => contracts.start(contract.id) : null,
        finish: () => contracts.finish(contract.id),
        onDone: reload,
      ),
    );

Widget _client(FakeContracts contracts, {VoidCallback? onPageReload}) =>
    Scaffold(
      body: SingleChildScrollView(
        child: ClientContractSection(
          load: () => contracts.getForRequest('req-1'),
          actionsBuilder: (context, contract, reload) => clientServiceActions(
            contract: contract,
            confirmClosure: () => contracts.confirmClosure('req-1'),
            object: (reason) => contracts.objectClosure('req-1', reason),
            onDone: () {
              reload();
              onPageReload?.call();
            },
          ),
        ),
      ),
    );

Future<void> _confirm(WidgetTester tester, String button, String action) async {
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, action).last);
  await tester.pumpAndSettle();
}

void main() {
  group('técnico', () {
    testWidgets('inicia y declara terminado; el estado sale del servidor',
        (tester) async {
      final contracts = _contracts(ServiceRequestStatus.contracted);
      await _pump(tester, _technician(contracts));

      expect(find.text('Declarar trabajo terminado'), findsNothing);
      await _confirm(tester, 'Iniciar servicio', 'Iniciar servicio');
      expect(find.text('Servicio iniciado.'), findsOneWidget);
      expect(find.text('En ejecución'), findsWidgets);

      await _confirm(
          tester, 'Declarar trabajo terminado', 'Declarar trabajo terminado');
      expect(find.text('Esperando que el cliente confirme el cierre.'),
          findsOneWidget);
      expect(find.text('Finalizada por el técnico'), findsWidgets);
      expect(contracts.actions, ['start', 'finish']);
    });

    testWidgets('sin iniciar disponible no ofrece acciones en contratada',
        (tester) async {
      await _pump(
          tester,
          _technician(_contracts(ServiceRequestStatus.contracted),
              withStart: false));
      expect(find.text('Iniciar servicio'), findsNothing);
      expect(find.text('Declarar trabajo terminado'), findsNothing);
    });

    testWidgets('un 409 no simula el cambio', (tester) async {
      final contracts = _contracts(ServiceRequestStatus.inProgress)
        ..actionError = const ContractFailure('El servicio ya fue finalizado.');
      await _pump(tester, _technician(contracts));
      await _confirm(
          tester, 'Declarar trabajo terminado', 'Declarar trabajo terminado');
      expect(find.text('El servicio ya fue finalizado.'), findsOneWidget);
      expect(find.text('Declarar trabajo terminado'), findsOneWidget);
    });

    testWidgets('volver en la confirmación no hace nada', (tester) async {
      final contracts = _contracts(ServiceRequestStatus.inProgress);
      await _pump(tester, _technician(contracts));
      await tester.tap(find.text('Declarar trabajo terminado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(contracts.actions, isEmpty);
    });
  });

  group('cliente', () {
    testWidgets('solo puede cerrar cuando el técnico declaró terminado',
        (tester) async {
      await _pump(tester, _client(_contracts(ServiceRequestStatus.inProgress)));
      expect(find.text('El técnico está trabajando en tu servicio.'),
          findsOneWidget);
      expect(find.text('Confirmar cierre'), findsNothing);
    });

    testWidgets('confirma el cierre', (tester) async {
      var pageReloads = 0;
      final contracts = _contracts(ServiceRequestStatus.technicianFinished);
      await _pump(
          tester, _client(contracts, onPageReload: () => pageReloads++));
      await _confirm(tester, 'Confirmar cierre', 'Confirmar cierre');

      expect(contracts.actions, ['closure']);
      expect(find.text('Servicio cerrado. ¡Gracias por usar Fixia!'),
          findsOneWidget);
      expect(find.text('Cerrada'), findsWidgets);
      expect(find.text('Confirmar cierre'), findsNothing);
      expect(pageReloads, 1);
    });

    testWidgets('objeta con motivo y el servicio vuelve a ejecución',
        (tester) async {
      final contracts = _contracts(ServiceRequestStatus.technicianFinished);
      await _pump(tester, _client(contracts));

      await tester.tap(find.text('Algo no quedó bien'));
      await tester.pumpAndSettle();
      // Sin motivo no envía.
      await tester.tap(find.widgetWithText(FilledButton, 'Algo no quedó bien'));
      await tester.pumpAndSettle();
      expect(find.text('Cuéntale al técnico qué falta.'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('objection-reason')), 'Sigue goteando');
      await tester.tap(find.widgetWithText(FilledButton, 'Algo no quedó bien'));
      await tester.pumpAndSettle();

      expect(contracts.actions, ['objection']);
      expect(find.text('El técnico está trabajando en tu servicio.'),
          findsOneWidget);
      expect(find.textContaining('Motivo: Sigue goteando'), findsOneWidget);
    });
  });
}
