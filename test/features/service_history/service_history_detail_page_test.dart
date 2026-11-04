import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/layout/app_shell.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/service_history/domain/service_evaluation.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_entry.dart';
import 'package:ms_frontend/features/service_history/presentation/service_history_detail_page.dart';
import 'package:ms_frontend/features/service_history/presentation/widgets/service_evaluations_view.dart';

import 'fake_service_history.dart';

Widget _page({
  required ServiceHistoryEntry entry,
  required Future<List<ServiceEvaluation>> Function() loadEvaluations,
}) =>
    ServiceHistoryDetailPage(
      entry: entry,
      destination: ShellDestination.clientServices,
      userId: clientUserId,
      contractSection: const Text('sección del contrato'),
      loadEvaluations: loadEvaluations,
    );

Future<void> _pump(
  WidgetTester tester, {
  required ServiceHistoryEntry entry,
  required Future<List<ServiceEvaluation>> Function() loadEvaluations,
}) async {
  tester.view.physicalSize = const Size(440, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    home: _page(entry: entry, loadEvaluations: loadEvaluations),
  ));
}

void main() {
  testWidgets('muestra la sección del contrato y las evaluaciones reales',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      entry: historyEntry('3'),
      loadEvaluations: () async => [
        evaluation('req-3',
            by: technicianUserId,
            to: clientUserId,
            rating: 4,
            comment: 'Cliente amable'),
        evaluation('req-3', by: clientUserId, to: technicianUserId),
      ],
    );
    expect(find.byKey(const ValueKey('service-evaluations-loading')),
        findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Plomería'), findsWidgets);
    expect(find.text('sección del contrato'), findsOneWidget);
    expect(find.text('Evaluaciones'), findsOneWidget);
    expect(find.text('Evaluación que recibiste'), findsOneWidget);
    expect(find.text('Tu evaluación'), findsOneWidget);
    expect(find.text('“Cliente amable”'), findsOneWidget);
    expect(find.byType(RatingStars), findsNWidgets(2));
    expect(find.bySemanticsLabel('4 de 5 estrellas'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('usa el marco de la app y vuelve a «Mis servicios»',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: FixiaTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _page(
                  entry: historyEntry('3'),
                  loadEvaluations: () async => const [],
                ),
              )),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(ServiceHistoryDetailPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('page-back')));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceHistoryDetailPage), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('servicio cerrado sin evaluaciones: lo dice sin estrellas',
      (tester) async {
    await _pump(tester,
        entry: historyEntry('3'), loadEvaluations: () async => const []);
    await tester.pumpAndSettle();

    expect(find.text(ServiceEvaluationsView.noneYetMessage), findsOneWidget);
    expect(find.byType(RatingStars), findsNothing);
  });

  testWidgets('servicio sin cerrar: explica cuándo se puede evaluar',
      (tester) async {
    await _pump(tester,
        entry: historyEntry('1', status: ServiceRequestStatus.inProgress),
        loadEvaluations: () async => const []);
    await tester.pumpAndSettle();

    expect(find.text(ServiceEvaluationsView.notClosedMessage), findsOneWidget);
  });

  testWidgets('si las evaluaciones fallan, se puede reintentar',
      (tester) async {
    var calls = 0;
    await _pump(tester, entry: historyEntry('3'), loadEvaluations: () async {
      calls++;
      if (calls == 1) throw Exception('No pudimos cargar las evaluaciones.');
      return const [];
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos cargar las evaluaciones.'),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('service-evaluations-retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text(ServiceEvaluationsView.noneYetMessage), findsOneWidget);
  });
}
