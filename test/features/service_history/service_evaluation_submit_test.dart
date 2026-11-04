import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/layout/app_shell.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/service_history/application/service_history_use_cases.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_entry.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_exceptions.dart';
import 'package:ms_frontend/features/service_history/infrastructure/http_service_history_repository.dart';
import 'package:ms_frontend/features/service_history/presentation/service_history_detail_page.dart';
import 'package:ms_frontend/features/service_history/presentation/widgets/service_evaluations_view.dart';

import 'fake_service_history.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

/// Detalle con evaluaciones y envío reales contra el fake, como lo arma
/// `main.dart`: después de enviar se vuelve a consultar.
Future<void> _pump(
  WidgetTester tester, {
  required FakeEvaluations evaluations,
  ServiceHistoryEntry? entry,
  String userId = clientUserId,
}) async {
  tester.view.physicalSize = const Size(1280, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final service = entry ?? historyEntry('3');
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    home: ServiceHistoryDetailPage(
      entry: service,
      destination: ShellDestination.clientServices,
      userId: userId,
      contractSection: const Text('sección del contrato'),
      loadEvaluations: () =>
          GetServiceEvaluations(evaluations)([service.serviceRequestId]),
      submitEvaluation: (rating, comment) =>
          SubmitServiceEvaluation(evaluations)(
              serviceRequestId: service.serviceRequestId,
              rating: rating,
              comment: comment),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _rate(WidgetTester tester, int stars, {String? comment}) async {
  await tester.tap(_key('service-evaluation-star-$stars'));
  if (comment != null) {
    await tester.enterText(_key('service-evaluation-comment'), comment);
  }
  await tester.pump();
}

void main() {
  testWidgets('el cliente califica al técnico y ve lo guardado en ms-users',
      (tester) async {
    final evaluations = FakeEvaluations();
    await _pump(tester, evaluations: evaluations);

    expect(find.text('Califica al técnico'), findsOneWidget);
    final submit = _key('service-evaluation-submit');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await _rate(tester, 4, comment: '  Muy puntual  ');
    expect(find.text('Bueno'), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(evaluations.submitted.single.rating, 4);
    expect(evaluations.submitted.single.comment, 'Muy puntual');
    // Se vuelve a consultar: lo mostrado es lo que guardó el servidor.
    expect(evaluations.requests, hasLength(2));
    expect(_key('service-evaluation-form'), findsNothing);
    expect(find.text(ServiceHistoryDetailPage.thanksMessage), findsOneWidget);
    expect(find.text('Tu evaluación'), findsOneWidget);
    expect(find.text('“Muy puntual”'), findsOneWidget);
  });

  testWidgets('el técnico califica al cliente', (tester) async {
    final evaluations = FakeEvaluations([
      evaluation('req-3', by: clientUserId, to: technicianUserId, rating: 5),
    ])
      ..evaluatorId = technicianUserId;
    await _pump(
      tester,
      evaluations: evaluations,
      entry: historyEntry('3', role: HistoryRole.professional),
      userId: technicianUserId,
    );

    expect(find.text('Evaluación que recibiste'), findsOneWidget);
    expect(find.text('Califica al cliente'), findsOneWidget);
    await _rate(tester, 5);
    await tester.tap(_key('service-evaluation-submit'));
    await tester.pumpAndSettle();

    expect(evaluations.submitted.single.comment, isNull);
    expect(find.text('Tu evaluación'), findsOneWidget);
    expect(find.byType(RatingStars), findsNWidgets(2));
  });

  testWidgets('si ya calificó, no se ofrece calificar de nuevo',
      (tester) async {
    await _pump(
      tester,
      evaluations: FakeEvaluations([
        evaluation('req-3', by: clientUserId, to: technicianUserId),
      ]),
    );

    expect(find.text('Tu evaluación'), findsOneWidget);
    expect(_key('service-evaluation-form'), findsNothing);
  });

  testWidgets('un servicio sin cerrar no se puede calificar', (tester) async {
    for (final status in [
      ServiceRequestStatus.contracted,
      ServiceRequestStatus.inProgress,
      ServiceRequestStatus.technicianFinished,
    ]) {
      await _pump(
        tester,
        evaluations: FakeEvaluations(),
        entry: historyEntry('1', status: status),
      );
      expect(_key('service-evaluation-form'), findsNothing);
      expect(
          find.text(ServiceEvaluationsView.notClosedMessage), findsOneWidget);
    }
  });

  testWidgets('sin envío conectado solo se muestran las evaluaciones',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: FixiaTheme.light,
      home: ServiceHistoryDetailPage(
        entry: historyEntry('3'),
        destination: ShellDestination.clientServices,
        userId: clientUserId,
        contractSection: const SizedBox(),
        loadEvaluations: () async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    expect(_key('service-evaluation-form'), findsNothing);
  });

  testWidgets('mientras se envía no se puede enviar dos veces', (tester) async {
    final evaluations = FakeEvaluations()..pendingSubmit = Completer<void>();
    await _pump(tester, evaluations: evaluations);

    await _rate(tester, 3);
    await tester.tap(_key('service-evaluation-submit'));
    await tester.pump();

    final submit = _key('service-evaluation-submit');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(
        tester.widget<IconButton>(_key('service-evaluation-star-5')).onPressed,
        isNull);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();
    expect(evaluations.submitted, hasLength(1));

    evaluations.pendingSubmit!.complete();
    await tester.pumpAndSettle();
    expect(find.text(ServiceHistoryDetailPage.thanksMessage), findsOneWidget);
  });

  testWidgets('un error que se puede reintentar deja el formulario',
      (tester) async {
    final evaluations = FakeEvaluations()
      ..submitFailure = const ServiceHistoryFailure(
          HttpServiceEvaluationRepository.verificationUnavailableMessage);
    await _pump(tester, evaluations: evaluations);

    await _rate(tester, 4);
    await tester.tap(_key('service-evaluation-submit'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            HttpServiceEvaluationRepository.verificationUnavailableMessage),
        findsOneWidget);
    expect(_key('service-evaluation-form'), findsOneWidget);

    evaluations.submitFailure = null;
    await tester.tap(_key('service-evaluation-submit'));
    await tester.pumpAndSettle();

    expect(evaluations.submitted, hasLength(2));
    expect(find.text(ServiceHistoryDetailPage.thanksMessage), findsOneWidget);
  });

  testWidgets('un rechazo del servidor quita el formulario y lo explica',
      (tester) async {
    const reason = 'Ya pasó el plazo para calificar este servicio.';
    final evaluations = FakeEvaluations()
      ..submitFailure = const ServiceHistoryFailure(reason, notAllowed: true);
    await _pump(tester, evaluations: evaluations);

    await _rate(tester, 4);
    await tester.tap(_key('service-evaluation-submit'));
    await tester.pumpAndSettle();

    expect(_key('service-evaluation-rejected'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    expect(_key('service-evaluation-form'), findsNothing);
  });

  testWidgets('si ya existía una evaluación suya, la muestra sin repetirla',
      (tester) async {
    final evaluations = FakeEvaluations()
      ..submitFailure = const ServiceHistoryFailure(
          HttpServiceEvaluationRepository.alreadyEvaluatedMessage,
          alreadyEvaluated: true);
    await _pump(tester, evaluations: evaluations);

    // Otra pestaña la registró mientras tanto.
    evaluations.items = [
      evaluation('req-3', by: clientUserId, to: technicianUserId, rating: 2),
    ];
    await _rate(tester, 4);
    await tester.tap(_key('service-evaluation-submit'));
    await tester.pumpAndSettle();

    expect(find.text(HttpServiceEvaluationRepository.alreadyEvaluatedMessage),
        findsOneWidget);
    expect(find.text('Tu evaluación'), findsOneWidget);
    expect(find.bySemanticsLabel('2 de 5 estrellas'), findsOneWidget);
    expect(_key('service-evaluation-form'), findsNothing);
  });
}
