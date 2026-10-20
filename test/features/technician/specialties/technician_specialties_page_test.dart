import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/specialties/presentation/technician_specialties_page.dart';

void main() {
  testWidgets('presenta categorías y subservicios locales', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: TechnicianSpecialtiesPage()),
    );

    expect(find.text('Mis especialidades'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Electricidad'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Electricidad'), findsOneWidget);
    expect(find.text('2 servicios activos'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('technician-specialties-save')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Guardar Cambios'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite seleccionar un subservicio y guardar localmente',
      (tester) async {
    Map<ServiceCategory, Set<String>>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: TechnicianSpecialtiesPage(onSaved: (value) => saved = value),
      ),
    );

    final categoryToggle = find.byKey(
      const ValueKey('technician-specialty-toggle-CARPENTRY'),
    );
    await tester.scrollUntilVisible(
      categoryToggle,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(categoryToggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carpintería'));
    await tester.pumpAndSettle();
    final subservice = find.byKey(
      const ValueKey(
        'technician-subservice-CARPENTRY-Armado de muebles',
      ),
    );
    await tester.scrollUntilVisible(
      subservice,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(subservice);
    await tester.pump();
    final save = find.byKey(const ValueKey('technician-specialties-save'));
    await tester.scrollUntilVisible(
      save,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pump();

    expect(
      saved![ServiceCategory.carpentry],
      contains('Armado de muebles'),
    );
    expect(
      find.text('Especialidades guardadas en esta demostración.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelar descarta la edición local', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TechnicianSpecialtiesPage()),
    );

    final categoryToggle = find.byKey(
      const ValueKey('technician-specialty-toggle-PAINTING'),
    );
    await tester.scrollUntilVisible(
      categoryToggle,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(categoryToggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pintura'));
    await tester.pumpAndSettle();
    final subservice =
        find.byKey(const ValueKey('technician-subservice-PAINTING-Pintura de interiores'));
    await tester.scrollUntilVisible(
      subservice,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(subservice);
    await tester.pump();
    final cancel = find.byKey(const ValueKey('technician-specialties-cancel'));
    await tester.scrollUntilVisible(
      cancel,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(cancel);
    await tester.pump();

    expect(find.text('Se descartaron los cambios sin guardar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la navegación inferior retorna a inicio o solicitudes',
      (tester) async {
    var homeOpens = 0;
    var opportunitiesOpen = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TechnicianSpecialtiesPage(
          onOpenHome: () => homeOpens++,
          onOpenOpportunities: () => opportunitiesOpen++,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('mobile-nav-inicio')));
    await tester.tap(find.byKey(const ValueKey('mobile-nav-trabajos')));

    expect(homeOpens, 1);
    expect(opportunitiesOpen, 1);
    expect(find.byKey(const ValueKey('mobile-nav-perfil')), findsOneWidget);
  });
}
