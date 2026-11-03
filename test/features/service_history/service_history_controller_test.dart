import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/features/service_history/application/service_history_use_cases.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_entry.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_exceptions.dart';
import 'package:ms_frontend/features/service_history/presentation/service_history_controller.dart';

import 'fake_service_history.dart';

ServiceHistoryController _controller(
  FakeServiceHistory history, [
  FakeEvaluations? evaluations,
]) =>
    ServiceHistoryController(
      listHistory: ListServiceHistory(history),
      getEvaluations: GetServiceEvaluations(evaluations ?? FakeEvaluations()),
    );

void main() {
  final active = historyEntry('1', status: ServiceRequestStatus.inProgress);
  final finished =
      historyEntry('2', status: ServiceRequestStatus.technicianFinished);
  final closed = historyEntry('3');

  test('carga la primera página con sus evaluaciones', () async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [active, closed], nextCursor: 'p2'),
    });
    final evaluations = FakeEvaluations([
      evaluation('req-3', by: clientUserId, to: technicianUserId, rating: 4),
    ]);
    final controller = _controller(history, evaluations);

    await controller.load();

    expect(controller.status, ServiceHistoryStatus.ready);
    expect(controller.entries, [active, closed]);
    expect(controller.hasMore, isTrue);
    expect(evaluations.requests.single, ['req-1', 'req-3']);
    expect(controller.evaluationsOf('req-3').single.rating, 4);
    expect(controller.evaluationsOf('req-1'), isEmpty);
  });

  test('sin servicios no consulta evaluaciones', () async {
    final evaluations = FakeEvaluations();
    final controller = _controller(FakeServiceHistory({}), evaluations);

    await controller.load();

    expect(controller.entries, isEmpty);
    expect(evaluations.requests, isEmpty);
  });

  test('el filtro distingue activos, finalizados y cerrados', () async {
    final controller = _controller(FakeServiceHistory({
      null: ServiceHistoryResult(items: [active, finished, closed]),
    }));
    await controller.load();

    controller.setFilter(HistoryStage.active);
    expect(controller.visibleEntries, [active]);
    controller.setFilter(HistoryStage.finished);
    expect(controller.visibleEntries, [finished]);
    controller.setFilter(HistoryStage.closed);
    expect(controller.visibleEntries, [closed]);
    controller.setFilter(null);
    expect(controller.visibleEntries, [active, finished, closed]);
  });

  test('cargar más agrega la siguiente página y sus evaluaciones', () async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [active], nextCursor: 'p2'),
      'p2': ServiceHistoryResult(items: [closed]),
    });
    final evaluations = FakeEvaluations();
    final controller = _controller(history, evaluations);
    await controller.load();

    await controller.loadMore();

    expect(history.requestedCursors, [null, 'p2']);
    expect(controller.entries, [active, closed]);
    expect(controller.hasMore, isFalse);
    expect(evaluations.requests, [
      ['req-1'],
      ['req-3'],
    ]);
    // Sin más páginas, no vuelve a pedir.
    await controller.loadMore();
    expect(history.requestedCursors, [null, 'p2']);
  });

  test('si falla cargar más, se conserva lo cargado y se avisa', () async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [active], nextCursor: 'p2'),
    });
    final controller = _controller(history);
    await controller.load();

    history.failure = const ServiceHistoryFailure('Sin conexión');
    await controller.loadMore();

    expect(controller.entries, [active]);
    expect(controller.loadMoreError, 'Sin conexión');
    expect(controller.hasMore, isTrue);
    expect(controller.isLoadingMore, isFalse);
  });

  test('si las evaluaciones fallan, el historial se muestra igual', () async {
    final evaluations = FakeEvaluations()
      ..failure = const ServiceHistoryFailure('ms-users caído');
    final controller = _controller(
      FakeServiceHistory({
        null: ServiceHistoryResult(items: [closed])
      }),
      evaluations,
    );

    await controller.load();

    expect(controller.status, ServiceHistoryStatus.ready);
    expect(controller.entries, [closed]);
    expect(controller.evaluationsUnavailable, isTrue);
  });

  test('una sesión vencida en las evaluaciones sí detiene la carga', () async {
    final evaluations = FakeEvaluations()
      ..failure =
          const ServiceHistoryFailure('vencida', isSessionExpired: true);
    final controller = _controller(
      FakeServiceHistory({
        null: ServiceHistoryResult(items: [closed])
      }),
      evaluations,
    );

    await controller.load();

    expect(controller.status, ServiceHistoryStatus.failure);
    expect(controller.sessionExpired, isTrue);
  });

  test('un error del historial queda con su mensaje y se puede reintentar',
      () async {
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [closed]),
    })
      ..failure = const ServiceHistoryFailure('No pudimos conectar.');
    final controller = _controller(history);

    await controller.load();
    expect(controller.status, ServiceHistoryStatus.failure);
    expect(controller.errorMessage, 'No pudimos conectar.');

    history.failure = null;
    await controller.load();
    expect(controller.status, ServiceHistoryStatus.ready);
    expect(controller.entries, [closed]);
  });

  test('un error inesperado usa el mensaje genérico', () async {
    final controller = ServiceHistoryController(
      listHistory: _ThrowingHistory(),
      getEvaluations: GetServiceEvaluations(FakeEvaluations()),
    );

    await controller.load();

    expect(controller.errorMessage,
        ServiceHistoryController.unexpectedErrorMessage);
  });

  test('recargar descarta una respuesta anterior que llega tarde', () async {
    final slow = Completer<void>();
    final history = FakeServiceHistory({
      null: ServiceHistoryResult(items: [active]),
    })
      ..pending = slow;
    final controller = _controller(history);
    final first = controller.load();

    history
      ..pending = null
      ..pages[null] = ServiceHistoryResult(items: [closed]);
    await controller.load();
    slow.complete();
    await first;

    expect(controller.entries, [closed]);
  });

  test('GetServiceEvaluations pide en tandas de 50 sin repetir ids', () async {
    final evaluations = FakeEvaluations();
    final ids = [for (var i = 0; i < 120; i++) 'req-$i', 'req-0'];

    await GetServiceEvaluations(evaluations)(ids);

    expect(evaluations.requests.map((r) => r.length), [50, 50, 20]);
  });
}

class _ThrowingHistory implements ListServiceHistory {
  @override
  Future<ServiceHistoryResult> call({String? cursor}) async =>
      throw StateError('inesperado');
}
