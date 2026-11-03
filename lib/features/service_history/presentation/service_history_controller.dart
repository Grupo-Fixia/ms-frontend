import 'package:flutter/foundation.dart';

import '../application/service_history_use_cases.dart';
import '../domain/service_evaluation.dart';
import '../domain/service_history_entry.dart';
import '../domain/service_history_exceptions.dart';

/// En qué punto está la consulta del historial.
enum ServiceHistoryStatus { idle, loading, ready, failure }

/// Estado del historial propio (GC-449): servicios cargados por páginas,
/// sus evaluaciones y el filtro por etapa. Todo sale del backend; recargar
/// vuelve a pedir la primera página.
class ServiceHistoryController extends ChangeNotifier {
  ServiceHistoryController({
    required ListServiceHistory listHistory,
    required GetServiceEvaluations getEvaluations,
  })  : _listHistory = listHistory,
        _getEvaluations = getEvaluations;

  final ListServiceHistory _listHistory;
  final GetServiceEvaluations _getEvaluations;

  static const unexpectedErrorMessage =
      'No pudimos cargar tu historial. Inténtalo de nuevo.';

  ServiceHistoryStatus _status = ServiceHistoryStatus.idle;
  List<ServiceHistoryEntry> _entries = const [];
  final Map<String, List<ServiceEvaluation>> _evaluations = {};
  String? _nextCursor;
  bool _loadingMore = false;
  String? _errorMessage;
  String? _loadMoreError;
  bool _evaluationsUnavailable = false;
  bool _sessionExpired = false;
  HistoryStage? _filter;
  int _request = 0;

  ServiceHistoryStatus get status => _status;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _nextCursor != null;

  /// Mensaje cuando la primera página falla ([status] es `failure`).
  String? get errorMessage => _errorMessage;

  /// Mensaje cuando falla cargar una página adicional; lo ya cargado sigue.
  String? get loadMoreError => _loadMoreError;

  /// Las evaluaciones no se pudieron consultar: se avisa sin inventarlas.
  bool get evaluationsUnavailable => _evaluationsUnavailable;
  bool get sessionExpired => _sessionExpired;

  /// Etapa elegida; `null` muestra todas.
  HistoryStage? get filter => _filter;

  /// Todos los servicios cargados, del más reciente al más antiguo.
  List<ServiceHistoryEntry> get entries => _entries;

  /// Los servicios cargados que corresponden al filtro.
  List<ServiceHistoryEntry> get visibleEntries => _filter == null
      ? _entries
      : List.unmodifiable(_entries.where((entry) => entry.stage == _filter));

  /// Evaluaciones de un servicio; vacía si no tiene.
  List<ServiceEvaluation> evaluationsOf(String serviceRequestId) =>
      _evaluations[serviceRequestId] ?? const [];

  void setFilter(HistoryStage? stage) {
    if (_filter == stage) return;
    _filter = stage;
    notifyListeners();
  }

  /// Consulta la primera página (al abrir y al recargar).
  Future<void> load() async {
    final request = ++_request;
    _status = ServiceHistoryStatus.loading;
    _errorMessage = null;
    _loadMoreError = null;
    _sessionExpired = false;
    notifyListeners();
    try {
      final page = await _listHistory();
      if (request != _request) return;
      _entries = List.unmodifiable(page.items);
      _nextCursor = page.nextCursor;
      _evaluations.clear();
      _evaluationsUnavailable = false;
      await _loadEvaluations(page.items, request);
      if (request != _request) return;
      _status = ServiceHistoryStatus.ready;
    } on ServiceHistoryFailure catch (failure) {
      if (request != _request) return;
      _errorMessage = failure.message;
      _sessionExpired = failure.isSessionExpired;
      _status = ServiceHistoryStatus.failure;
    } catch (_) {
      if (request != _request) return;
      _errorMessage = unexpectedErrorMessage;
      _status = ServiceHistoryStatus.failure;
    }
    notifyListeners();
  }

  /// Agrega la siguiente página, si la hay.
  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null ||
        _loadingMore ||
        _status != ServiceHistoryStatus.ready) {
      return;
    }
    final request = _request;
    _loadingMore = true;
    _loadMoreError = null;
    notifyListeners();
    try {
      final page = await _listHistory(cursor: cursor);
      if (request != _request) return;
      _entries = List.unmodifiable([..._entries, ...page.items]);
      _nextCursor = page.nextCursor;
      await _loadEvaluations(page.items, request);
    } on ServiceHistoryFailure catch (failure) {
      if (request != _request) return;
      _loadMoreError = failure.message;
      _sessionExpired = failure.isSessionExpired;
    } catch (_) {
      if (request != _request) return;
      _loadMoreError = unexpectedErrorMessage;
    } finally {
      if (request == _request) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Si las evaluaciones fallan, el historial se muestra igual y se avisa
  /// que no se pudieron consultar. Una sesión vencida sí se propaga.
  Future<void> _loadEvaluations(
      List<ServiceHistoryEntry> entries, int request) async {
    if (entries.isEmpty) return;
    try {
      final evaluations =
          await _getEvaluations(entries.map((e) => e.serviceRequestId));
      if (request != _request) return;
      for (final evaluation in evaluations) {
        (_evaluations[evaluation.serviceRequestId] ??= []).add(evaluation);
      }
    } on ServiceHistoryFailure catch (failure) {
      if (failure.isSessionExpired) rethrow;
      _evaluationsUnavailable = true;
    } catch (_) {
      _evaluationsUnavailable = true;
    }
  }
}
