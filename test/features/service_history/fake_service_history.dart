import 'dart:async';

import 'package:ms_frontend/core/constants/service_category.dart';
import 'package:ms_frontend/core/domain/service_budget.dart';
import 'package:ms_frontend/features/service_history/application/ports/service_history_repository.dart';
import 'package:ms_frontend/features/service_history/domain/service_evaluation.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_entry.dart';
import 'package:ms_frontend/features/service_history/domain/service_history_exceptions.dart';

const clientUserId = '3f6c1c0e-5d0a-4a8f-9d6e-0a1b2c3d4e5f';
const technicianUserId = 'tec-1';

ServiceHistoryEntry historyEntry(
  String id, {
  ServiceRequestStatus? status = ServiceRequestStatus.closed,
  HistoryRole role = HistoryRole.client,
  ServiceCategory? category = ServiceCategory.plumbing,
  DateTime? startedAt,
  DateTime? finishedAt,
  DateTime? closedAt,
}) =>
    ServiceHistoryEntry(
      serviceRequestId: 'req-$id',
      contractId: 'con-$id',
      role: role,
      counterpartId:
          role == HistoryRole.client ? technicianUserId : clientUserId,
      category: category,
      status: status,
      contractedAmount: ServiceBudget.tryParse('180000')!,
      budget: ServiceBudget.tryParse('200000'),
      agreedAt: DateTime.utc(2026, 10, 28, 15),
      contractedAt: DateTime.utc(2026, 10, 25, 14),
      startedAt: startedAt,
      finishedAt: finishedAt,
      closedAt: closedAt,
    );

ServiceEvaluation evaluation(
  String requestId, {
  required String by,
  required String to,
  int rating = 5,
  String? comment,
}) =>
    ServiceEvaluation(
      serviceRequestId: requestId,
      direction: by == clientUserId
          ? EvaluationDirection.clientToProvider
          : EvaluationDirection.providerToClient,
      evaluatorId: by,
      evaluatedId: to,
      rating: rating,
      comment: comment,
    );

/// Historial de prueba: devuelve las páginas configuradas por cursor.
class FakeServiceHistory implements ServiceHistoryRepository {
  FakeServiceHistory(this.pages);

  /// Página que corresponde a cada cursor (`null` es la primera).
  final Map<String?, ServiceHistoryResult> pages;
  ServiceHistoryFailure? failure;
  Completer<void>? pending;
  final requestedCursors = <String?>[];

  @override
  Future<ServiceHistoryResult> listPage(
      {String? cursor, int limit = 20}) async {
    requestedCursors.add(cursor);
    await pending?.future;
    if (failure != null) throw failure!;
    return pages[cursor] ?? const ServiceHistoryResult(items: []);
  }
}

/// Evaluaciones de prueba: solo devuelve las de los ids pedidos.
class FakeEvaluations implements ServiceEvaluationRepository {
  FakeEvaluations([this.items = const []]);

  List<ServiceEvaluation> items;
  ServiceHistoryFailure? failure;
  final requests = <List<String>>[];

  @override
  Future<List<ServiceEvaluation>> listFor(
      List<String> serviceRequestIds) async {
    requests.add(serviceRequestIds);
    if (failure != null) throw failure!;
    return items
        .where((e) => serviceRequestIds.contains(e.serviceRequestId))
        .toList();
  }

  /// Si se configura, `submit` falla con esto.
  ServiceHistoryFailure? submitFailure;
  Completer<void>? pendingSubmit;
  final submitted = <NewServiceEvaluation>[];

  /// Quién evalúa en las evaluaciones registradas por `submit`.
  String evaluatorId = clientUserId;

  @override
  Future<ServiceEvaluation> submit(NewServiceEvaluation evaluation) async {
    submitted.add(evaluation);
    await pendingSubmit?.future;
    if (submitFailure != null) throw submitFailure!;
    final saved = ServiceEvaluation(
      serviceRequestId: evaluation.serviceRequestId,
      direction: evaluatorId == clientUserId
          ? EvaluationDirection.clientToProvider
          : EvaluationDirection.providerToClient,
      evaluatorId: evaluatorId,
      evaluatedId:
          evaluatorId == clientUserId ? technicianUserId : clientUserId,
      rating: evaluation.rating,
      comment: evaluation.comment,
    );
    items = [...items, saved];
    return saved;
  }
}
