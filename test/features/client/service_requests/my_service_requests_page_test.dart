import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';
import 'package:ms_frontend/features/client/service_requests/presentation/my_service_requests_page.dart';

ServiceRequest item(String id, String? budget) => ServiceRequest(
      id: id,
      category: ServiceCategory.plumbing,
      description: id,
      status: ServiceRequestStatus.published,
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
    await tester.tap(find.byTooltip('Actualizar solicitudes'));
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
}
