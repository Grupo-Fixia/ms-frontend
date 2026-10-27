import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';
import 'package:ms_frontend/features/technician/applications/presentation/my_application_prices_page.dart';
import 'package:ms_frontend/core/constants/service_category.dart';

ServiceApplication item(String id, ProposedPrice? price) => ServiceApplication(
    id: id,
    status: ApplicationStatus.applied,
    proposedPrice: price,
    serviceRequest: const ApplicationRequestSummary(
        id: 'r1',
        category: ServiceCategory.plumbing,
        city: 'Bogotá',
        zone: 'Suba'));

void main() {
  testWidgets(
      'muestra precio real recibido y ausencia histórica sin inventar valor',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MyApplicationPricesPage(
      loadApplications: () async =>
          [item('1', ProposedPrice.tryParse('180000,25')), item('2', null)],
    )));
    await tester.pumpAndSettle();
    expect(find.text('180.000,25 COP'), findsOneWidget);
    expect(find.text('Precio no informado'), findsOneWidget);
  });

  testWidgets(
      'refrescar vuelve a consultar y fallo no conserva un precio obsoleto',
      (tester) async {
    var fail = false;
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: MyApplicationPricesPage(
      loadApplications: () async {
        calls++;
        if (fail) throw StateError('detalle interno');
        return [item('1', ProposedPrice.tryParse('150000'))];
      },
    )));
    await tester.pumpAndSettle();
    fail = true;
    await tester.tap(find.byTooltip('Actualizar postulaciones'));
    await tester.pumpAndSettle();
    expect(find.text('150.000 COP'), findsNothing);
    expect(find.textContaining('detalle interno'), findsNothing);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(find.text('150.000 COP'), findsOneWidget);
  });

  testWidgets('lista vacía es estado explícito', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MyApplicationPricesPage(loadApplications: () async => [])));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no tienes postulaciones.'), findsOneWidget);
  });
}
