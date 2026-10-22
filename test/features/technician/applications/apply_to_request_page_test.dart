import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/technician/applications/application/application_use_cases.dart';
import 'package:ms_frontend/features/technician/applications/domain/application_exceptions.dart';
import 'package:ms_frontend/features/technician/applications/infrastructure/mock_application_repository.dart';
import 'package:ms_frontend/features/technician/opportunities/application/list_compatible_opportunities.dart';
import 'package:ms_frontend/features/technician/opportunities/application/ports/opportunity_repository.dart';
import 'package:ms_frontend/features/technician/opportunities/domain/opportunity.dart';
import 'package:ms_frontend/features/technician/opportunities/presentation/technician_opportunities_page.dart';

Future<void> _openApplyConfirmation(WidgetTester tester) async {
  final detail = find.byKey(
    const ValueKey('technician-opportunity-detail-fuga-lavaplatos'),
  );
  await tester.ensureVisible(detail);
  await tester.tap(detail);
  await tester.pumpAndSettle();
  await tester
      .tap(find.byKey(const ValueKey('technician-apply-fuga-lavaplatos')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('apply-confirm-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Widget _page(MockApplicationRepository repository, {VoidCallback? onExpired}) =>
    MaterialApp(
      theme: FixiaTheme.light,
      home: TechnicianOpportunitiesPage(
        applyToServiceRequest: ApplyToServiceRequest(repository),
        onSessionExpired: onExpired,
      ),
    );

void main() {
  setUp(() {});

  testWidgets('GC-344: postulación exitosa marca la solicitud como postulada',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockApplicationRepository(latency: Duration.zero);

    await tester.pumpWidget(_page(repository));
    await _openApplyConfirmation(tester);

    expect(
      find.text('Postulación enviada. El cliente revisará tu perfil.'),
      findsOneWidget,
    );
    expect(find.text('Postulada'), findsOneWidget);
    expect((await repository.listMine()).single.serviceRequest.id,
        'fuga-lavaplatos');
  });

  testWidgets('GC-344: 409 duplicado informa que ya se postuló',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockApplicationRepository(latency: Duration.zero);
    await repository.apply('fuga-lavaplatos');

    await tester.pumpWidget(_page(repository));
    await _openApplyConfirmation(tester);

    expect(find.text('Ya te postulaste a esta solicitud.'), findsOneWidget);
    expect(find.text('Postulada'), findsOneWidget);
  });

  testWidgets('GC-344: restricción de verificación muestra el motivo',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository =
        MockApplicationRepository(latency: Duration.zero, failures: {
      'fuga-lavaplatos': const ApplicationFailure(
        'No puedes postularte a esta solicitud.',
        reasons: [IneligibilityReason.verification],
      ),
    });

    await tester.pumpWidget(_page(repository));
    await _openApplyConfirmation(tester);

    expect(find.byKey(const ValueKey('apply-failure-dialog')), findsOneWidget);
    expect(find.text('• Tu perfil aún no está verificado.'), findsOneWidget);
    expect(find.text('Postulada'), findsNothing);
  });

  testWidgets('GC-344: sesión expirada avisa a la app', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var expired = 0;
    final repository =
        MockApplicationRepository(latency: Duration.zero, failures: {
      'fuga-lavaplatos':
          const ApplicationFailure('Sesión', isSessionExpired: true),
    });

    await tester.pumpWidget(_page(repository, onExpired: () => expired++));
    await _openApplyConfirmation(tester);

    expect(expired, 1);
  });

  testWidgets('sin solicitudes reales muestra las de ejemplo y postula local',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockApplicationRepository(latency: Duration.zero);

    await tester.pumpWidget(
      MaterialApp(
        theme: FixiaTheme.light,
        home: TechnicianOpportunitiesPage(
          listOpportunities: ListCompatibleOpportunities(_EmptyRepository()),
          applyToServiceRequest: ApplyToServiceRequest(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openApplyConfirmation(tester);

    expect(find.text('Postulada'), findsOneWidget);
    expect(await repository.listMine(), isEmpty);
  });
}

class _EmptyRepository implements OpportunityRepository {
  @override
  Future<OpportunityPage> fetchPage(
          {required int limit, String? cursor}) async =>
      const OpportunityPage(items: <Opportunity>[]);
}
