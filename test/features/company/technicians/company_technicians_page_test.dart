import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/company/technicians/application/company_use_cases.dart';
import 'package:ms_frontend/features/company/technicians/domain/company_exceptions.dart';
import 'package:ms_frontend/features/company/technicians/presentation/company_technicians_controller.dart';
import 'package:ms_frontend/features/company/technicians/presentation/company_technicians_page.dart';
import 'package:ms_frontend/features/company/technicians/presentation/widgets/associated_technician_tile.dart';

import 'fake_company_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeCompanyRepository repository, {
  VoidCallback? onSessionExpired,
  VoidCallback? onBack,
}) async {
  tester.view.physicalSize = const Size(440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    home: CompanyTechniciansPage(
      controller:
          CompanyTechniciansController(ListCompanyTechnicians(repository)),
      onBack: onBack ?? () {},
      onSessionExpired: onSessionExpired ?? () {},
    ),
  ));
}

void main() {
  testWidgets('consulta al abrir y muestra los técnicos reales',
      (tester) async {
    final repository = FakeCompanyRepository(pending: Completer<void>());
    await _pump(tester, repository);
    await tester.pump();

    expect(find.byKey(const ValueKey('company-technicians-loading')),
        findsOneWidget);

    repository.pending!.complete();
    await tester.pumpAndSettle();

    expect(repository.techniciansCalls, 1);
    expect(find.text('2 técnicos'), findsOneWidget);
    expect(find.byType(AssociatedTechnicianTile), findsNWidgets(2));
    expect(find.text('Carlos G.'), findsOneWidget);
    expect(find.text('Verificado'), findsOneWidget);
    expect(find.textContaining('Plomería · Electricidad'), findsOneWidget);
    expect(find.textContaining('6 años de experiencia'), findsOneWidget);
    expect(find.text('Pendiente de verificación'), findsOneWidget);
  });

  testWidgets('una empresa sin técnicos ve el mensaje, sin técnicos ficticios',
      (tester) async {
    await _pump(tester, FakeCompanyRepository(technicians: const []));
    await tester.pumpAndSettle();

    expect(find.text(CompanyTechniciansPage.emptyMessage), findsOneWidget);
    expect(find.byType(AssociatedTechnicianTile), findsNothing);
  });

  testWidgets('un solo técnico se cuenta en singular', (tester) async {
    await _pump(tester,
        FakeCompanyRepository(technicians: [fixtureTechnicians.first]));
    await tester.pumpAndSettle();

    expect(find.text('1 técnico'), findsOneWidget);
  });

  testWidgets('un error se muestra y se puede reintentar', (tester) async {
    final repository = FakeCompanyRepository(
        failure: const CompanyFailure('No pudimos conectar con Fixia.'));
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('No pudimos conectar con Fixia.'), findsOneWidget);

    repository.failure = null;
    await tester.tap(find.byKey(const ValueKey('company-technicians-retry')));
    await tester.pumpAndSettle();

    expect(repository.techniciansCalls, 2);
    expect(find.byType(AssociatedTechnicianTile), findsNWidgets(2));
  });

  testWidgets('si la sesión vence, avisa una sola vez para volver al login',
      (tester) async {
    var expired = 0;
    await _pump(
      tester,
      FakeCompanyRepository(
          failure: const CompanyFailure('vencida', isSessionExpired: true)),
      onSessionExpired: () => expired++,
    );
    await tester.pumpAndSettle();

    expect(expired, 1);
  });

  testWidgets('el botón atrás usa el callback', (tester) async {
    var back = false;
    await _pump(tester, FakeCompanyRepository(), onBack: () => back = true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Volver').first);
    await tester.pumpAndSettle();

    expect(back, isTrue);
  });

  testWidgets('el tile seleccionado se marca y responde al toque',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: FixiaTheme.light,
      home: Scaffold(
        body: AssociatedTechnicianTile(
          technician: fixtureTechnicians.first,
          selected: true,
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('CG'), findsOneWidget);
    await tester.tap(find.byType(AssociatedTechnicianTile));
    expect(tapped, isTrue);
  });
}
