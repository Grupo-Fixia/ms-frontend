import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/opportunities/presentation/technician_opportunities_page.dart';

void main() {
  testWidgets('muestra solicitudes mock con ubicación y presupuesto',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const TechnicianOpportunitiesPage(),
      ),
    );

    expect(find.text('Oportunidades para ti'), findsOneWidget);
    expect(find.text('Reparar fuga bajo el lavaplatos'), findsOneWidget);
    expect(find.text('\$80.000 – \$140.000'), findsOneWidget);
    expect(find.text('Ubicación aproximada'), findsAtLeastNWidgets(1));
    expect(find.text('5 solicitudes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra por categoría y cambia el estado de postulación',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? appliedId;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: TechnicianOpportunitiesPage(
          onApply: (id) => appliedId = id,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Plomería'));
    await tester.pumpAndSettle();
    expect(find.text('1 solicitudes'), findsOneWidget);
    expect(find.text('Reparar fuga bajo el lavaplatos'), findsOneWidget);
    expect(find.text('Instalar ventilador de techo'), findsNothing);

    final detail = find.byKey(
      const ValueKey('technician-opportunity-detail-fuga-lavaplatos'),
    );
    await tester.ensureVisible(detail);
    await tester.tap(detail);
    await tester.pumpAndSettle();
    expect(find.text('Descripción'), findsOneWidget);
    expect(find.text('Momento esperado'), findsOneWidget);
    final apply = find.byKey(
      const ValueKey('technician-apply-fuga-lavaplatos'),
    );
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(appliedId, 'fuga-lavaplatos');
    expect(
        find.text('Postulación enviada en esta demostración.'), findsOneWidget);
    expect(
      find.text('Postulada'),
      findsOneWidget,
    );
  });

  testWidgets('en computador usa menú lateral y varias columnas',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: TechnicianOpportunitiesPage()),
    );

    final first = tester.getRect(
      find.byKey(const ValueKey('technician-opportunity-fuga-lavaplatos')),
    );
    expect(first.left, greaterThan(248));
    // Las tarjetas se reparten en columnas: no ocupan todo el ancho.
    expect(first.width, lessThan(600));
    expect(find.byKey(const ValueKey('technician-nav-oportunidades')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el menú navega a inicio y especialidades',
      (tester) async {
    var homeOpens = 0;
    var specialtiesOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TechnicianOpportunitiesPage(
          onOpenHome: () => homeOpens++,
          onOpenSpecialties: () => specialtiesOpens++,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('technician-nav-inicio')));
    await tester.tap(
      find.byKey(const ValueKey('technician-opportunities-specialties')),
    );
    expect(homeOpens, 1);
    expect(specialtiesOpens, 1);
  });

  testWidgets('en celular se ven todas las categorías sin desplazar',
      (tester) async {
    tester.view.physicalSize = const Size(340, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
          theme: FixiaTheme.light, home: const TechnicianOpportunitiesPage()),
    );

    final filters =
        find.byKey(const ValueKey('technician-opportunities-filters'));
    final area = tester.getRect(filters);
    for (final category in ServiceCategory.values) {
      final chip = tester.getRect(find.widgetWithText(ChoiceChip, category.label));
      expect(chip.right, lessThanOrEqualTo(area.right + 0.5));
      expect(chip.left, greaterThanOrEqualTo(area.left - 0.5));
    }
    expect(tester.takeException(), isNull);
  });
}
