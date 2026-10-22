import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/features/technician/specialties/application/get_service_catalog.dart';
import 'package:ms_frontend/features/technician/specialties/application/get_technician_specialties.dart';
import 'package:ms_frontend/features/technician/specialties/application/ports/technician_specialties_repository.dart';
import 'package:ms_frontend/features/technician/specialties/application/update_technician_specialties.dart';
import 'package:ms_frontend/features/technician/specialties/domain/technician_specialties.dart';
import 'package:ms_frontend/features/technician/specialties/domain/technician_specialties_exceptions.dart';
import 'package:ms_frontend/features/technician/specialties/infrastructure/demo_technician_specialties_repository.dart';
import 'package:ms_frontend/features/technician/specialties/presentation/technician_specialties_page.dart';

class _FailingRepository implements TechnicianSpecialtiesRepository {
  _FailingRepository(this.failure);

  final TechnicianSpecialtiesFailure failure;

  @override
  Future<List<ServiceCategoryOption>> fetchCatalog() async => throw failure;

  @override
  Future<TechnicianSpecialties> fetchSpecialties() async => throw failure;

  @override
  Future<TechnicianSpecialties> updateSpecialties(
    Set<ServiceCategory> categories,
  ) async =>
      throw failure;
}

Widget _page(
  TechnicianSpecialtiesRepository repository, {
  VoidCallback? onSessionExpired,
  VoidCallback? onOpenHome,
  VoidCallback? onOpenOpportunities,
}) {
  return MaterialApp(
    home: TechnicianSpecialtiesPage(
      getCatalog: GetServiceCatalog(repository),
      getSpecialties: GetTechnicianSpecialties(repository),
      updateSpecialties: UpdateTechnicianSpecialties(repository),
      onSessionExpired: onSessionExpired,
      onOpenHome: onOpenHome,
      onOpenOpportunities: onOpenOpportunities,
    ),
  );
}

void main() {
  testWidgets('muestra el catálogo y la selección del repositorio',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_page(DemoTechnicianSpecialtiesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Mis especialidades'), findsOneWidget);
    expect(find.text('Plomería'), findsOneWidget);
    expect(find.text('2 especialidades activas'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(
            const ValueKey('technician-specialty-toggle-PLUMBING'),
          ))
          .value,
      isTrue,
    );
  });

  testWidgets('guarda la nueva selección con el caso de uso', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = DemoTechnicianSpecialtiesRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('technician-specialties-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('technician-specialty-toggle-CARPENTRY')),
    );
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final saved = await repository.fetchSpecialties();
    expect(saved.categories, contains(ServiceCategory.carpentry));
    expect(find.text('Especialidades guardadas.'), findsOneWidget);
  });

  testWidgets('cancelar descarta la edición local', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_page(DemoTechnicianSpecialtiesRepository()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('technician-specialty-toggle-PAINTING')),
    );
    await tester.pump();
    expect(find.text('3 especialidades activas'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('technician-specialties-cancel')));
    await tester.pump();

    expect(find.text('2 especialidades activas'), findsOneWidget);
    expect(
        find.text('Se descartaron los cambios sin guardar.'), findsOneWidget);
  });

  testWidgets('un error de carga permite reintentar', (tester) async {
    await tester.pumpWidget(
      _page(_FailingRepository(
        const TechnicianSpecialtiesFailure('No pudimos cargar'),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('technician-specialties-retry')),
      findsOneWidget,
    );
  });

  testWidgets('si la sesión vence avisa para volver al login', (tester) async {
    var expired = 0;
    await tester.pumpWidget(
      _page(
        _FailingRepository(
          const TechnicianSpecialtiesFailure('x', isSessionExpired: true),
        ),
        onSessionExpired: () => expired++,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(expired, 1);
  });

  testWidgets('la navegación inferior retorna a inicio o solicitudes',
      (tester) async {
    var homeOpens = 0;
    var opportunitiesOpen = 0;
    await tester.pumpWidget(
      _page(
        DemoTechnicianSpecialtiesRepository(),
        onOpenHome: () => homeOpens++,
        onOpenOpportunities: () => opportunitiesOpen++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-nav-inicio')));
    await tester.tap(find.byKey(const ValueKey('mobile-nav-trabajos')));

    expect(homeOpens, 1);
    expect(opportunitiesOpen, 1);
    expect(find.byKey(const ValueKey('mobile-nav-perfil')), findsOneWidget);
  });
}
