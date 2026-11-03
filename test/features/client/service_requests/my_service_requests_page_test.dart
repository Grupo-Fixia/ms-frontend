import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/my_service_requests_page.dart';

ServiceRequest item(String id, String? budget,
        [ServiceRequestStatus status = ServiceRequestStatus.published]) =>
    ServiceRequest(
      id: id,
      category: ServiceCategory.plumbing,
      description: id,
      status: status,
      approximateLocation:
          const ApproximateLocation(city: 'Bogotá', zone: 'Chapinero'),
      expectedAt: DateTime.utc(2027),
      budget: budget == null ? null : ServiceBudget.tryParse(budget),
    );
void main() {
  testWidgets(
      'lista presupuesto real e histórico y consulta detalle actualizado',
      (tester) async {
    String? queried;
    await tester.pumpWidget(MaterialApp(
        home: MyServiceRequestsPage(
      load: () async => [item('actual', '200000'), item('histórica', null)],
      get: (id) async {
        queried = id;
        return item(id, '200000.25');
      },
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('200.000 COP'), findsOneWidget);
    expect(find.textContaining('Presupuesto no informado'), findsOneWidget);
    await tester.tap(find.text('actual'));
    await tester.pumpAndSettle();
    expect(queried, 'actual');
    expect(find.textContaining('200.000,25 COP'), findsOneWidget);
  });
  testWidgets('consulta fallida permite actualizar sin mostrar datos ficticios',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(MaterialApp(
        home: MyServiceRequestsPage(
      load: () async {
        if (fail) throw const ServiceRequestFailure('Consulta fallida');
        return [];
      },
      get: (id) async => item(id, null),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Consulta fallida'), findsOneWidget);
    fail = false;
    await tester.tap(find.byKey(const ValueKey('client-requests-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no tienes solicitudes.'), findsOneWidget);
  });
  testWidgets('error de detalle no presenta un presupuesto guardado',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MyServiceRequestsPage(
      load: () async => [item('actual', '200000')],
      get: (_) async =>
          throw const ServiceRequestFailure('Detalle no disponible'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('actual'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle no disponible'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('filtra por estado y en celular muestra tarjetas',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    var publish = 0;
    await tester.pumpWidget(MaterialApp(
        home: MyServiceRequestsPage(
      load: () async => [
        item('abierta', '100000'),
        item('en-curso', null, ServiceRequestStatus.inProgress),
        item('cerrada', null, ServiceRequestStatus.closed),
      ],
      get: (id) async => item(id, null),
      onOpen: (r) async => opened.add(r.id),
      onPublish: () => publish++,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Todas (3)'), findsOneWidget);
    expect(find.text('Abiertas (1)'), findsOneWidget);

    await tester.tap(find.text('En curso (1)'));
    await tester.pumpAndSettle();
    expect(find.text('en-curso'), findsOneWidget);
    expect(find.text('abierta'), findsNothing);

    await tester.tap(find.text('Finalizadas (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cerrada'));
    await tester.pumpAndSettle();
    expect(opened, ['cerrada']);

    final publishButton = find.byKey(const ValueKey('client-requests-publish'));
    await tester.ensureVisible(publishButton);
    await tester.tap(publishButton);
    expect(publish, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en computador las solicitudes se ven en tabla', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: MyServiceRequestsPage(
      load: () async => [item('abierta', '100000')],
      get: (id) async => item(id, null),
    )));
    await tester.pumpAndSettle();
    expect(find.text('SOLICITUD'), findsOneWidget);
    expect(find.text('PRESUPUESTO'), findsOneWidget);
    expect(find.text('No hay solicitudes con este filtro.'), findsNothing);
  });
}
