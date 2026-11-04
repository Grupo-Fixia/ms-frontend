import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/layout/app_shell.dart';
import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:ms_frontend/features/service_history/application/service_history_use_cases.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_entry.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_exceptions.dart';
import 'package:ms_frontend/features/service_history/presentation/service_history_controller.dart';
import 'package:ms_frontend/features/service_history/presentation/service_history_page.dart';
import 'package:ms_frontend/features/service_history/presentation/widgets/service_evaluations_view.dart';

import 'fake_service_history.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

Future<ServiceHistoryController> _pump(
  WidgetTester tester,
  FakeServiceHistory history, {
  FakeEvaluations? evaluations,
  Future<void> Function(ServiceHistoryEntry entry)? onOpen,
  VoidCallback? onSessionExpired,
  Size size = const Size(440, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = ServiceHistoryController(
    listHistory: ListServiceHistory(history),
    getEvaluations: GetServiceEvaluations(evaluations ?? FakeEvaluations()),
  );
  await tester.pumpWidget(MaterialApp(
    theme: FixiaTheme.light,
    home: ServiceHistoryPage(
      controller: controller,
      destination: ShellDestination.clientServices,
      userId: clientUserId,
      onOpen: onOpen ?? (_) async {},
      onSessionExpired: onSessionExpired ?? () {},
    ),
  ));
  return controller;
}

void main() {
  final active = historyEntry('1',
      status: ServiceRequestStatus.inProgress,
      startedAt: DateTime.utc(2026, 10, 26, 13));
  final finished = historyEntry('2',
      status: ServiceRequestStatus.technicianFinished,
      category: null,
      finishedAt: DateTime.utc(2026, 10, 29, 17));
  final closed = historyEntry('3', closedAt: DateTime.utc(2026, 10, 30, 18));

  testWidgets(
      'consulta al abrir y muestra servicios con estado y fechas reales',
      (tester) async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [active, finished, closed]),
    })
      ..pending = Completer<void>();
    await _pump(tester, history);
    await tester.pump();
    expect(_key('service-history-loading'), findsOneWidget);

    history.pending!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Mis servicios'), findsWidgets);
    expect(find.text('En ejecución'), findsOneWidget);
    expect(find.text('Finalizada por el técnico'), findsOneWidget);
    expect(find.text('Cerrada'), findsOneWidget);
    expect(_key('service-history-stage-active'), findsOneWidget);
    expect(_key('service-history-stage-finished'), findsOneWidget);
    expect(_key('service-history-stage-closed'), findsOneWidget);
    expect(find.text('Precio contratado: 180.000 COP'), findsNWidgets(3));
    expect(find.textContaining('Iniciado:'), findsOneWidget);
    expect(find.textContaining('Terminado por el técnico:'), findsOneWidget);
    expect(find.textContaining('Cerrado:'), findsOneWidget);
    expect(find.text('Servicio'), findsOneWidget); // categoría desconocida
    expect(find.text('Como cliente'), findsNWidgets(3));
  });

  testWidgets('en pantallas anchas los servicios se ven en tabla',
      (tester) async {
    await _pump(
      tester,
      FakeServiceHistory({
        null: ServiceHistoryResult(items: [active, closed]),
      }),
      size: const Size(1280, 1200),
    );
    await tester.pumpAndSettle();

    expect(find.text('SERVICIO'), findsOneWidget);
    expect(find.text('EVALUACIÓN'), findsOneWidget);
    expect(find.text('180.000 COP'), findsNWidgets(2));
    expect(_key('service-history-con-1'), findsOneWidget);
    expect(_key('service-history-con-3'), findsOneWidget);
  });

  for (final width in [620.0, 700.0, 800.0, 1024.0, 1100.0]) {
    testWidgets('la tabla no se desborda a ${width.toInt()} px',
        (tester) async {
      await _pump(
        tester,
        FakeServiceHistory({
          null: ServiceHistoryResult(items: [active, finished, closed]),
        }),
        evaluations: FakeEvaluations([
          evaluation('req-3', by: technicianUserId, to: clientUserId),
          evaluation('req-3', by: clientUserId, to: technicianUserId),
        ]),
        size: Size(width, 1600),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Finalizada por el técnico'), findsOneWidget);
    });
  }

  testWidgets('los filtros separan activos, finalizados y cerrados',
      (tester) async {
    await _pump(
        tester,
        FakeServiceHistory({
          null: ServiceHistoryResult(items: [active, finished, closed]),
        }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activos (1)'));
    await tester.pumpAndSettle();
    expect(_key('service-history-con-1'), findsOneWidget);
    expect(_key('service-history-con-2'), findsNothing);
    expect(_key('service-history-con-3'), findsNothing);

    await tester.tap(find.text('Finalizados (1)'));
    await tester.pumpAndSettle();
    expect(_key('service-history-con-2'), findsOneWidget);
    expect(_key('service-history-con-1'), findsNothing);

    await tester.tap(find.text('Cerrados (1)'));
    await tester.pumpAndSettle();
    expect(_key('service-history-con-3'), findsOneWidget);
    expect(_key('service-history-con-2'), findsNothing);

    await tester.tap(find.text('Todos (3)'));
    await tester.pumpAndSettle();
    expect(_key('service-history-con-1'), findsOneWidget);
    expect(_key('service-history-con-2'), findsOneWidget);
    expect(_key('service-history-con-3'), findsOneWidget);
  });

  testWidgets('al abrir de nuevo, el filtro anterior no se arrastra',
      (tester) async {
    final controller = await _pump(
        tester,
        FakeServiceHistory({
          null: ServiceHistoryResult(items: [active, closed]),
        }));
    await tester.pumpAndSettle();
    controller.setFilter(HistoryStage.closed);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      theme: FixiaTheme.light,
      home: ServiceHistoryPage(
        controller: controller,
        destination: ShellDestination.clientServices,
        userId: clientUserId,
        onOpen: (_) async {},
        onSessionExpired: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(controller.filter, isNull);
    expect(_key('service-history-con-1'), findsOneWidget);
    expect(_key('service-history-con-3'), findsOneWidget);
  });

  testWidgets('un filtro sin resultados lo dice', (tester) async {
    await _pump(
        tester,
        FakeServiceHistory({
          null: ServiceHistoryResult(items: [closed]),
        }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activos (0)'));
    await tester.pumpAndSettle();

    expect(find.text('No hay servicios con este filtro.'), findsOneWidget);
  });

  testWidgets('con más páginas, el filtro vacío sugiere cargar más',
      (tester) async {
    await _pump(
        tester,
        FakeServiceHistory({
          null: ServiceHistoryResult(items: [closed], nextCursor: 'p2'),
        }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activos (0)'));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Carga más para seguir buscando'), findsOneWidget);
  });

  testWidgets('«Cargar más» agrega la siguiente página', (tester) async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [active], nextCursor: 'p2'),
      'p2': ServiceHistoryResult(items: [closed]),
    });
    await _pump(tester, history);
    await tester.pumpAndSettle();

    await tester.tap(_key('service-history-load-more'));
    await tester.pumpAndSettle();

    expect(history.requestedCursors, [null, 'p2']);
    expect(_key('service-history-con-3'), findsOneWidget);
    expect(_key('service-history-load-more'), findsNothing);
  });

  testWidgets('si falla cargar más, lo cargado sigue y se muestra el error',
      (tester) async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [active], nextCursor: 'p2'),
    });
    await _pump(tester, history);
    await tester.pumpAndSettle();

    history.failure = const ServiceHistoryFailure('No pudimos conectar.');
    await tester.tap(_key('service-history-load-more'));
    await tester.pumpAndSettle();

    expect(_key('service-history-con-1'), findsOneWidget);
    expect(find.text('No pudimos conectar.'), findsOneWidget);
    expect(_key('service-history-load-more'), findsOneWidget);
  });

  testWidgets('muestra las evaluaciones que existen, sin inventar otras',
      (tester) async {
    await _pump(
      tester,
      FakeServiceHistory({
        null: ServiceHistoryResult(items: [active, closed]),
      }),
      evaluations: FakeEvaluations([
        evaluation('req-3', by: technicianUserId, to: clientUserId, rating: 4),
        evaluation('req-3', by: clientUserId, to: technicianUserId),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recibiste '), findsOneWidget);
    expect(find.text('Calificaste '), findsOneWidget);
    expect(find.byType(RatingStars), findsNWidgets(2));
    expect(find.text('Sin evaluaciones'), findsOneWidget); // el activo
  });

  testWidgets('si las evaluaciones no cargan, lo avisa y muestra el historial',
      (tester) async {
    await _pump(
      tester,
      FakeServiceHistory({
        null: ServiceHistoryResult(items: [closed]),
      }),
      evaluations: FakeEvaluations()
        ..failure = const ServiceHistoryFailure('caído'),
    );
    await tester.pumpAndSettle();

    expect(_key('service-history-evaluations-unavailable'), findsOneWidget);
    expect(_key('service-history-con-3'), findsOneWidget);
    expect(find.byType(RatingStars), findsNothing);
  });

  testWidgets('sin servicios muestra el mensaje vacío', (tester) async {
    await _pump(tester, FakeServiceHistory({}));
    await tester.pumpAndSettle();

    expect(find.text(ServiceHistoryPage.emptyMessage), findsOneWidget);
  });

  testWidgets('un error se muestra y se puede reintentar', (tester) async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [closed]),
    })
      ..failure = const ServiceHistoryFailure('No pudimos conectar con Fixia.');
    await _pump(tester, history);
    await tester.pumpAndSettle();
    expect(find.text('No pudimos conectar con Fixia.'), findsOneWidget);

    history.failure = null;
    await tester.tap(_key('service-history-retry'));
    await tester.pumpAndSettle();

    expect(_key('service-history-con-3'), findsOneWidget);
  });

  testWidgets('«Actualizar» vuelve a consultar el historial', (tester) async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [closed]),
    });
    await _pump(tester, history);
    await tester.pumpAndSettle();

    await tester.tap(_key('service-history-refresh'));
    await tester.pumpAndSettle();

    expect(history.requestedCursors, [null, null]);
  });

  testWidgets('abrir un servicio y volver recarga el historial persistido',
      (tester) async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [closed]),
    });
    ServiceHistoryEntry? opened;
    await _pump(tester, history, onOpen: (entry) async => opened = entry);
    await tester.pumpAndSettle();

    await tester.tap(_key('service-history-con-3'));
    await tester.pumpAndSettle();

    expect(opened, closed);
    expect(history.requestedCursors, [null, null]);
  });

  testWidgets('si la sesión vence, avisa una sola vez', (tester) async {
    var expired = 0;
    await _pump(
      tester,
      FakeServiceHistory({})
        ..failure =
            const ServiceHistoryFailure('vencida', isSessionExpired: true),
      onSessionExpired: () => expired++,
    );
    await tester.pumpAndSettle();

    expect(expired, 1);
  });
}
