import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/service_opportunity.dart';
import 'package:ms_frontend/features/technician/dashboard/presentation/technician_dashboard_page.dart';
import 'package:ms_frontend/features/technician/profile/domain/verification_status.dart';

void main() {
  ServiceOpportunity opportunity(String id, String title) => ServiceOpportunity(
        id: id,
        title: title,
        category: ServiceCategory.plumbing,
        postedLabel: 'Hace 5 min',
        budget: '150.000 COP',
        approximateLocation: 'Chapinero, Bogotá',
        description: title,
        expectedMoment: '02/11/2026 · 09:00',
      );

  testWidgets('sin conexión no muestra datos de ejemplo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const TechnicianDashboardPage(),
      ),
    );

    expect(find.text('Técnico'), findsOneWidget);
    expect(find.text('Carlos Mendoza'), findsNothing);
    expect(find.text('4.8'), findsNothing);
    expect(find.text('Reparar fuga bajo el lavaplatos'), findsNothing);
    expect(find.text('Solicitar Retiro'), findsNothing);
    expect(find.text('Billetera'), findsNothing);
    expect(find.text('–'), findsNWidgets(3));
    expect(
      find.text(
          'Las oportunidades aparecerán aquí cuando te conectes a Fixia.'),
      findsOneWidget,
    );
    expect(find.text('Disponible para trabajos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra oportunidades y contadores reales', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: TechnicianDashboardPage(
          firstName: 'Laura Mora',
          loadOpportunities: () async => [
            for (var i = 1; i <= 4; i++) opportunity('o$i', 'Fuga número $i'),
          ],
          loadStats: () async =>
              const TechnicianWorkStats(toQuote: 1, active: 2, closed: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LM'), findsOneWidget);
    expect(find.text('Por cotizar'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    // Solo las tres primeras; el resto en la pantalla de oportunidades.
    expect(find.text('Fuga número 1'), findsOneWidget);
    expect(find.text('Fuga número 3'), findsOneWidget);
    expect(find.text('Fuga número 4'), findsNothing);
    expect(find.text('150.000 COP'), findsNWidgets(3));
  });

  testWidgets('sin oportunidades lo dice; con error permite reintentar',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: TechnicianDashboardPage(
          loadOpportunities: () async {
            if (fail) throw Exception('Sin conexión');
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    fail = false;
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('No hay solicitudes compatibles'), findsOneWidget);
  });

  testWidgets('Postularme identifica la oportunidad o abre las oportunidades',
      (tester) async {
    String? applied;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: TechnicianDashboardPage(
          loadOpportunities: () async => [opportunity('o1', 'Fuga')],
          onApplyToOpportunity: (id) => applied = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('technician-apply-o1'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(applied, 'o1');

    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: TechnicianDashboardPage(
          loadOpportunities: () async => [opportunity('o1', 'Fuga')],
          onOpenOpportunities: () => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(opened, 1);
    expect(find.text('PENDIENTE'), findsOneWidget);
  });

  testWidgets('el acceso al perfil notifica que la demo no tiene sesión',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TechnicianDashboardPage()),
    );

    await tester.tap(find.byKey(const ValueKey('technician-nav-perfil')));
    await tester.pump();

    expect(
      find.text(
        'El perfil profesional existe para cuentas autenticadas; esta demo no tiene una sesión activa.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('los accesos al perfil técnico usan el callback disponible',
      (tester) async {
    var profileOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TechnicianDashboardPage(onOpenSettings: () => profileOpens++),
      ),
    );

    await tester
        .tap(find.byKey(const ValueKey('technician-dashboard-profile')));

    expect(profileOpens, 1);
  });

  testWidgets('enlaza accesos demo de solicitudes y especialidades',
      (tester) async {
    var opportunitiesOpens = 0;
    var specialtiesOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TechnicianDashboardPage(
          onOpenOpportunities: () => opportunitiesOpens++,
          onOpenSpecialties: () => specialtiesOpens++,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('technician-nav-trabajos')));
    final specialties = find.byKey(
      const ValueKey('technician-open-specialties'),
    );
    await tester.scrollUntilVisible(
      specialties,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(specialties);

    expect(opportunitiesOpens, 1);
    expect(specialtiesOpens, 1);
  });

  testWidgets('la disponibilidad se puede cambiar de forma local',
      (tester) async {
    bool? availability;
    await tester.pumpWidget(
      MaterialApp(
        home: TechnicianDashboardPage(
          onAvailabilityChanged: (value) => availability = value,
        ),
      ),
    );

    await tester
        .tap(find.byKey(const ValueKey('technician-availability-switch')));
    await tester.pump();

    expect(availability, isFalse);
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('No recibirás solicitudes nuevas'), findsOneWidget);
  });

  for (final entry in {
    VerificationStatus.pending: 'PENDIENTE',
    VerificationStatus.valid: 'VIGENTE',
    VerificationStatus.rejected: 'RECHAZADA',
    VerificationStatus.expired: 'VENCIDA',
  }.entries) {
    testWidgets('presenta el estado ${entry.value}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FixiaTheme.light,
          home: TechnicianDashboardPage(verificationStatus: entry.key),
        ),
      );

      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('no desborda en pantalla móvil de 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: TechnicianDashboardPage()),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('en navegador mantiene el layout limitado a formato móvil',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: TechnicianDashboardPage()),
    );

    final wallet = tester.getRect(
      find.byKey(const ValueKey('technician-verification-banner')),
    );
    expect(wallet.width, lessThanOrEqualTo(404));
    expect(wallet.center.dx, closeTo(640, 1));
    expect(tester.takeException(), isNull);
  });
}
