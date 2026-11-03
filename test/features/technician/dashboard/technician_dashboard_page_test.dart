import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/contracts/domain/service_contract.dart';
import 'package:ms_frontend/features/technician/applications/domain/service_application.dart';
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

  ServiceApplication selected(String id) => ServiceApplication(
        id: id,
        status: ApplicationStatus.selected,
        proposedPrice: ProposedPrice.tryParse('120000'),
        serviceRequest: ApplicationRequestSummary(
          id: 'req-$id',
          category: ServiceCategory.plumbing,
          city: 'Bogotá',
          zone: 'Chapinero',
        ),
      );

  ServiceContract contract(String id, ServiceRequestStatus status) =>
      ServiceContract(
        id: id,
        serviceRequestId: 'req-$id',
        quotationId: 'q-$id',
        clientId: 'cli-1',
        providerId: 'tec-1',
        amountInCents: 15000000,
        currency: 'COP',
        scope: 'Cambio de tubo',
        conditions: 'Garantía 30 días',
        agreedAt: DateTime.utc(2029, 12, 2, 15),
        contractedAt: DateTime.utc(2029, 12, 1),
        request: const ContractedRequest(
          category: ServiceCategory.plumbing,
          description: 'Fuga en la cocina',
          city: 'Bogotá',
          zone: 'Chapinero',
        ),
        serviceStatus: status,
      );

  Future<void> pumpPage(WidgetTester tester, Widget page,
      {Size size = const Size(1280, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: FixiaTheme.light, home: page));
  }

  testWidgets('sin conexión no muestra datos de ejemplo', (tester) async {
    await pumpPage(tester, const TechnicianDashboardPage());

    expect(find.text('Técnico'), findsWidgets);
    expect(find.text('Carlos Mendoza'), findsNothing);
    expect(find.text('4.8'), findsNothing);
    expect(find.text('Billetera'), findsNothing);
    expect(find.text('–'), findsNWidgets(3));
    expect(
      find.text(
          'Las oportunidades aparecerán aquí cuando te conectes a Fixia.'),
      findsOneWidget,
    );
    expect(
      find.text('Tus trabajos aparecerán aquí cuando te conectes a Fixia.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra oportunidades, trabajos y contadores reales',
      (tester) async {
    await pumpPage(
      tester,
      TechnicianDashboardPage(
        firstName: 'Laura Mora',
        loadOpportunities: () async => [
          for (var i = 1; i <= 5; i++) opportunity('o$i', 'Fuga número $i'),
        ],
        loadWork: () async => TechnicianWork(
          toQuote: [selected('a1')],
          contracts: [
            contract('c1', ServiceRequestStatus.inProgress),
            contract('c2', ServiceRequestStatus.contracted),
            contract('c3', ServiceRequestStatus.closed),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, Laura Mora'), findsOneWidget);
    expect(find.text('LM'), findsOneWidget);
    expect(find.text('Por cotizar'), findsOneWidget);
    expect(
      find.text('Tienes 1 cotización por enviar y 2 servicios en curso.'),
      findsOneWidget,
    );
    // Solo las primeras; el resto en la pantalla de oportunidades.
    expect(find.text('Fuga número 1'), findsOneWidget);
    expect(find.text('Fuga número 4'), findsOneWidget);
    expect(find.text('Fuga número 5'), findsNothing);
    expect(
      find.byKey(const ValueKey('technician-home-quote-a1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('technician-home-contract-c1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('technician-home-contract-c3')),
        findsNothing);
  });

  testWidgets('abre cotización y contrato y vuelve a cargar', (tester) async {
    var loads = 0;
    ServiceApplication? quoted;
    ServiceContract? opened;
    await pumpPage(
      tester,
      TechnicianDashboardPage(
        loadWork: () async {
          loads++;
          return TechnicianWork(
            toQuote: [selected('a1')],
            contracts: [contract('c1', ServiceRequestStatus.contracted)],
          );
        },
        onOpenQuotation: (a) async => quoted = a,
        onOpenContract: (c) async => opened = c,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enviar cotización'));
    await tester.pumpAndSettle();
    expect(quoted?.id, 'a1');
    await tester.tap(find.text('Ver contrato'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'c1');
    expect(loads, 3);
  });

  testWidgets('sin pendientes lo dice', (tester) async {
    await pumpPage(
      tester,
      TechnicianDashboardPage(
        loadWork: () async => const TechnicianWork(toQuote: [], contracts: []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No tienes pendientes'), findsOneWidget);
    expect(
        find.textContaining('Cuando un cliente te seleccione'), findsOneWidget);
  });

  testWidgets('errores de carga permiten reintentar', (tester) async {
    var fail = true;
    await pumpPage(
      tester,
      TechnicianDashboardPage(
        loadOpportunities: () async {
          if (fail) throw Exception('Sin conexión');
          return [];
        },
        loadWork: () async {
          if (fail) throw Exception('Trabajos caídos');
          return const TechnicianWork(toQuote: [], contracts: []);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(find.textContaining('Trabajos caídos'), findsOneWidget);
    fail = false;
    for (final retry in find.text('Reintentar').evaluate().toList()) {
      await tester.tap(find.byWidget(retry.widget));
    }
    await tester.pumpAndSettle();
    expect(
        find.textContaining('No hay solicitudes compatibles'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('Postularme identifica la oportunidad o abre las oportunidades',
      (tester) async {
    String? applied;
    await pumpPage(
      tester,
      TechnicianDashboardPage(
        loadOpportunities: () async => [opportunity('o1', 'Fuga')],
        onApplyToOpportunity: (id) => applied = id,
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('technician-apply-o1'));
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
    await tester.tap(button);
    expect(opened, 1);
    expect(find.text('PENDIENTE'), findsOneWidget);
  });

  testWidgets('sin sesión el perfil avisa que hay que iniciar sesión',
      (tester) async {
    await pumpPage(tester, const TechnicianDashboardPage());

    await tester.tap(find.byKey(const ValueKey('technician-nav-perfil')));
    await tester.pump();

    expect(
      find.text('Inicia sesión como técnico para ver tu perfil.'),
      findsOneWidget,
    );
  });

  testWidgets('menú y accesos usan los callbacks disponibles', (tester) async {
    var profile = 0, opportunities = 0, jobs = 0, specialties = 0;
    var availability = 0, chat = 0, logout = 0;
    await pumpPage(
      tester,
      TechnicianDashboardPage(
        onOpenSettings: () => profile++,
        onOpenOpportunities: () => opportunities++,
        onOpenJobs: () => jobs++,
        onOpenSpecialties: () => specialties++,
        onOpenAvailability: () async => availability++,
        onOpenChat: () => chat++,
        onLogout: () => logout++,
      ),
    );

    for (final key in [
      'technician-dashboard-settings',
      'technician-nav-perfil',
      'technician-nav-oportunidades',
      'technician-see-opportunities',
      'technician-nav-trabajos',
      'technician-open-jobs',
      'technician-open-specialties',
      'technician-open-availability',
      'technician-open-chat-prototype',
      'technician-dashboard-logout',
    ]) {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.tap(target);
    }

    expect(profile, 2);
    expect(opportunities, 2);
    expect(jobs, 2);
    expect(specialties, 1);
    expect(availability, 1);
    expect(chat, 1);
    expect(logout, 1);
  });

  for (final entry in {
    VerificationStatus.pending: 'PENDIENTE',
    VerificationStatus.valid: 'VIGENTE',
    VerificationStatus.rejected: 'RECHAZADA',
    VerificationStatus.expired: 'VENCIDA',
  }.entries) {
    testWidgets('presenta el estado ${entry.value}', (tester) async {
      await pumpPage(
        tester,
        TechnicianDashboardPage(verificationStatus: entry.key),
      );

      expect(find.text(entry.value), findsOneWidget);
      expect(find.byKey(const ValueKey('technician-verification-banner')),
          findsOneWidget);
    });
  }

  for (final size in const [Size(320, 812), Size(834, 1112)]) {
    testWidgets('no desborda en ${size.width.toInt()} px', (tester) async {
      await pumpPage(
        tester,
        TechnicianDashboardPage(
          firstName: 'Laura',
          loadOpportunities: () async => [opportunity('o1', 'Fuga')],
          loadWork: () async => TechnicianWork(
            toQuote: [selected('a1')],
            contracts: [contract('c1', ServiceRequestStatus.inProgress)],
          ),
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('en escritorio usa el ancho disponible con menú lateral',
      (tester) async {
    await pumpPage(tester, const TechnicianDashboardPage(),
        size: const Size(1440, 900));

    final banner = tester.getRect(
      find.byKey(const ValueKey('technician-verification-banner')),
    );
    expect(banner.width, greaterThan(800));
    expect(banner.left, greaterThan(248));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin horario y zona avisa y al configurar se revisa de nuevo',
      (tester) async {
    var complete = false;
    var opened = 0;
    await pumpPage(
      tester,
      TechnicianDashboardPage(
        loadSetupComplete: () async => complete,
        onOpenAvailability: () async {
          opened++;
          complete = true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('technician-setup-banner')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('technician-setup-configure')));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byKey(const ValueKey('technician-setup-banner')), findsNothing);
  });
}
