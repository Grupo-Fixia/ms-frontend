import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/dashboard/presentation/technician_dashboard_page.dart';
import 'package:ms_frontend/features/technician/profile/domain/verification_status.dart';

void main() {
  testWidgets('muestra oportunidades, trabajos asignados y billetera',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const TechnicianDashboardPage(),
      ),
    );

    expect(find.text('Carlos Mendoza'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Oportunidades Disponibles'), findsOneWidget);
    expect(find.text('Reparar fuga bajo el lavaplatos'), findsOneWidget);
    expect(find.text('Instalar ventilador de techo'), findsOneWidget);
    expect(find.text('Reparación de circuito en cocina'), findsOneWidget);
    expect(find.text('Ubicación aproximada'), findsNWidgets(4));
    expect(find.text('\$80.000 – \$140.000'), findsOneWidget);
    expect(find.text('Disponible para trabajos'), findsOneWidget);
    expect(find.text('3 nuevas'), findsOneWidget);
    expect(find.text('URGENTE'), findsNWidgets(2));
    expect(find.text('Trabajos Asignados / En Curso'), findsOneWidget);
    expect(find.text('Registrar Avance / Evidencia'), findsOneWidget);
    expect(find.text('Marcar Finalizado'), findsOneWidget);
    expect(find.text('Saldo disponible'), findsOneWidget);
    expect(find.text('Saldo retenido'), findsOneWidget);
    expect(find.text('Solicitar Retiro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bloquea postulación mientras la cuenta está pendiente',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: const TechnicianDashboardPage(),
      ),
    );

    final applyButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('technician-apply')),
    );
    expect(applyButton.onPressed, isNull);
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(
      find.textContaining('Tu cuenta está en proceso de verificación'),
      findsOneWidget,
    );
  });

  testWidgets('habilita postulación solo con verificación vigente',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TechnicianDashboardPage(
          verificationStatus: VerificationStatus.valid,
        ),
      ),
    );

    final applyButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('technician-apply')),
    );
    expect(applyButton.onPressed, isNotNull);
    expect(find.text('VIGENTE'), findsOneWidget);
  });

  testWidgets('la postulación identifica la oportunidad elegida',
      (tester) async {
    String? appliedOpportunity;
    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: TechnicianDashboardPage(
          verificationStatus: VerificationStatus.valid,
          onApplyToOpportunity: (opportunityId) =>
              appliedOpportunity = opportunityId,
        ),
      ),
    );

    final button = find.byKey(const ValueKey('technician-apply'));
    await tester.ensureVisible(button);
    await tester.tap(button);

    expect(appliedOpportunity, 'plumbing-repair');
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
      find.byKey(const ValueKey('technician-wallet-summary')),
    );
    expect(wallet.width, lessThanOrEqualTo(404));
    expect(wallet.center.dx, closeTo(640, 1));
    expect(tester.takeException(), isNull);
  });
}
