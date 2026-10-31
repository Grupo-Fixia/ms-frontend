import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/client/dashboard/presentation/client_dashboard_page.dart';
import 'package:ms_frontend/features/client/profile/presentation/client_profile_page.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request.dart';
import 'package:ms_frontend/features/client/service_requests/domain/service_request_exceptions.dart';

ServiceRequest _request(String id, ServiceRequestStatus status) =>
    ServiceRequest(
      id: id,
      category: ServiceCategory.plumbing,
      description: 'Solicitud $id',
      status: status,
      approximateLocation:
          const ApproximateLocation(city: 'Bogotá', zone: 'Chapinero'),
      expectedAt: DateTime.utc(2030),
    );

void main() {
  testWidgets('sin conexión no muestra técnicos ni servicios de ejemplo',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: FixiaTheme.light, home: const ClientDashboardPage()),
    );
    expect(find.text('Ana García'), findsNothing);
    expect(find.text('Recomendados para ti'), findsNothing);
    expect(find.text('Mantenimiento de calentador'), findsNothing);
    expect(find.text('3 postulantes'), findsNothing);
    expect(
      find.text('Tus solicitudes aparecerán aquí cuando te conectes a Fixia.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra las solicitudes reales recientes y lo que falta hacer',
      (tester) async {
    final opened = <String>[];
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: ClientDashboardPage(
          firstName: 'Ana',
          loadRequests: () async {
            loads++;
            return [
              _request('a', ServiceRequestStatus.providerSelected),
              _request('b', ServiceRequestStatus.technicianFinished),
              _request('c', ServiceRequestStatus.closed),
              _request('d', ServiceRequestStatus.published),
            ];
          },
          onOpenRequest: (request) async => opened.add(request.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Solicitud a'), findsOneWidget);
    expect(find.text('Revisa la cotización'), findsOneWidget);
    expect(find.text('Confirma el cierre'), findsOneWidget);
    expect(find.text('Cerrada'), findsOneWidget);
    // Solo las tres más recientes.
    expect(find.text('Solicitud d'), findsNothing);

    await tester.ensureVisible(find.text('Solicitud b'));
    await tester.tap(find.text('Solicitud b'));
    await tester.pumpAndSettle();
    expect(opened, ['b']);
    expect(loads, 2);
  });

  testWidgets('sin solicitudes invita a publicar; con error permite reintentar',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: ClientDashboardPage(
          loadRequests: () async {
            if (fail) throw const ServiceRequestFailure('Sin conexión');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    fail = false;
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no has publicado solicitudes'),
        findsOneWidget);
  });

  test('acciones pendientes por estado', () {
    expect(pendingActionFor(ServiceRequestStatus.published),
        'Revisa los postulantes');
    expect(pendingActionFor(ServiceRequestStatus.inProgress), isNull);
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
    expect(find.text('Bienvenido a Fixia'), findsOneWidget);
  });

  testWidgets('el encabezado ya no muestra la campana de notificaciones',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: FixiaTheme.light, home: const ClientDashboardPage()),
    );

    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(
      find.byKey(const ValueKey('client-dashboard-settings')),
      findsNothing,
    );
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
      find.byKey(const ValueKey('client-dashboard-publish')),
    );
    expect(card.width, lessThanOrEqualTo(404));
    expect(card.center.dx, closeTo(640, 1));
    expect(tester.takeException(), isNull);
  });
}
