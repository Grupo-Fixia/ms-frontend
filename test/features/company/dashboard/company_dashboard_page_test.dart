import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/company/dashboard/presentation/company_dashboard_page.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Future<String> Function() loadCompanyName,
  VoidCallback? onOpenTechnicians,
  VoidCallback? onLogout,
  VoidCallback? onOpenOpportunities,
}) async {
  tester.view.physicalSize = const Size(440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    home: CompanyDashboardPage(
      firstName: 'Laura',
      loadCompanyName: loadCompanyName,
      onOpenTechnicians: onOpenTechnicians ?? () {},
      onLogout: onLogout ?? () {},
      onOpenOpportunities: onOpenOpportunities,
    ),
  ));
}

void main() {
  testWidgets('saluda al administrador y muestra el nombre real de la empresa',
      (tester) async {
    await _pump(tester,
        loadCompanyName: () async => 'Servicios Integrales Andina');

    expect(find.byKey(const ValueKey('company-name-loading')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Hola, Laura'), findsOneWidget);
    expect(find.text('Servicios Integrales Andina'), findsOneWidget);
  });

  testWidgets('sin la pantalla de GC-469 no ofrece oportunidades',
      (tester) async {
    await _pump(tester, loadCompanyName: () async => 'Andina');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('company-open-technicians')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('company-open-opportunities')),
        findsNothing);
  });

  testWidgets('las acciones usan sus callbacks', (tester) async {
    var technicians = false;
    var opportunities = false;
    var logout = false;
    await _pump(
      tester,
      loadCompanyName: () async => 'Andina',
      onOpenTechnicians: () => technicians = true,
      onOpenOpportunities: () => opportunities = true,
      onLogout: () => logout = true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('company-open-technicians')));
    await tester.tap(find.byKey(const ValueKey('company-open-opportunities')));
    await tester.tap(find.byKey(const ValueKey('company-logout')));

    expect(technicians, isTrue);
    expect(opportunities, isTrue);
    expect(logout, isTrue);
  });

  testWidgets('si no carga el nombre muestra el error y permite reintentar',
      (tester) async {
    var calls = 0;
    await _pump(tester, loadCompanyName: () async {
      calls++;
      if (calls == 1) throw Exception('No pudimos conectar con Fixia.');
      return 'Andina';
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('No pudimos conectar con Fixia.'),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('company-name-retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Andina'), findsOneWidget);
  });
}
