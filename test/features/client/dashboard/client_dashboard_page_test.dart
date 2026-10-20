import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/client/dashboard/presentation/client_dashboard_page.dart';
import 'package:ms_frontend/features/client/profile/presentation/client_profile_page.dart';

void main() {
  testWidgets('muestra el catálogo de técnicos con acciones y datos mock',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const ClientDashboardPage(),
      ),
    );

    expect(find.text('Encuentra tu técnico'), findsOneWidget);
    expect(find.text('Usaquén, Bogotá'), findsOneWidget);
    expect(find.text('Ana García'), findsOneWidget);
    expect(find.text('Pedro Rojas'), findsOneWidget);
    expect(find.text('Laura Torres'), findsOneWidget);
    expect(find.text('4.8 (64)'), findsOneWidget);
    expect(find.text('\$70.000'), findsOneWidget);
    expect(find.text('Solicitar'), findsNWidgets(4));
    expect(find.text('Ubicación aproximada'), findsNWidgets(9));
    expect(find.text('3 postulantes'), findsOneWidget);
    expect(find.byTooltip('Abrir chat'), findsOneWidget);
    expect(find.byTooltip('Revisar cotización'), findsOneWidget);
    expect(find.byTooltip('Confirmar cierre'), findsOneWidget);
    expect(find.byKey(const ValueKey('client-nav-historial')), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la acción Solicitar identifica al técnico seleccionado',
      (tester) async {
    String? requestedTechnician;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: ClientDashboardPage(
          onRequestTechnician: (technicianId) =>
              requestedTechnician = technicianId,
        ),
      ),
    );

    final requestButton =
        find.byKey(const ValueKey('client-request-ana-garcia'));
    await tester.ensureVisible(requestButton);
    await tester.pumpAndSettle();
    await tester.tap(requestButton);

    expect(requestedTechnician, 'ana-garcia');
  });

  testWidgets('filtra técnicos por categoría y texto de búsqueda',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const ClientDashboardPage(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('client-category-Plomería')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('client-technician-ana-garcia')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-technician-pedro-rojas')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('client-technician-search')),
      'Ana',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('client-technician-ana-garcia')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('client-clear-filters')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('client-technician-ana-garcia')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('client-technician-pedro-rojas')),
      findsOneWidget,
    );
  });

  testWidgets('muestra estado vacío cuando los filtros no tienen resultados',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const ClientDashboardPage(),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('client-technician-search')),
      'carpintería',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('client-no-technicians-found')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('client-technician-ana-garcia')),
      findsNothing,
    );
  });

  testWidgets('el acceso al perfil del cliente solicita una sesión',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const ClientDashboardPage(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('client-nav-perfil')));
    await tester.pump();

    expect(
      find.text(
        'Inicia sesión como cliente para consultar y editar tu perfil.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el acceso a Perfil delega la navegación a la pantalla indicada',
      (tester) async {
    var profileOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: ClientDashboardPage(onOpenProfile: () => profileOpens++),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('client-nav-perfil')));

    expect(profileOpens, 1);
  });

  testWidgets('navega del dashboard al perfil y de vuelta sin conexión',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        initialRoute: '/dashboard',
        routes: {
          '/dashboard': (context) => ClientDashboardPage(
                onOpenProfile: () =>
                    Navigator.of(context).pushNamed('/profile'),
              ),
          '/profile': (context) => ClientProfilePage(
                firstName: 'Ana',
                lastName: 'Pérez',
                email: 'ana@fixia.com',
                onOpenHome: () =>
                    Navigator.of(context).pushReplacementNamed('/dashboard'),
              ),
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('client-nav-perfil')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('client-profile-title')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('client-profile-nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Encuentra tu técnico'), findsOneWidget);
  });

  testWidgets('el botón Publicar usa el callback correspondiente',
      (tester) async {
    var publishCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: ClientDashboardPage(onPublishProblem: () => publishCalls++),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('client-publish-problem')));

    expect(publishCalls, 1);
  });

  for (final width in [320.0, 375.0]) {
    testWidgets('no desborda en pantalla de $width px', (tester) async {
      tester.view.physicalSize = Size(width, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: FixiaTheme.light,
          home: const ClientDashboardPage(),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('en navegador mantiene el layout limitado a formato móvil',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const ClientDashboardPage(),
      ),
    );

    final card = tester.getRect(
      find.byKey(const ValueKey('client-technician-ana-garcia')),
    );
    expect(card.width, lessThanOrEqualTo(404));
    expect(card.center.dx, closeTo(640, 1));
    expect(tester.takeException(), isNull);
  });
}
