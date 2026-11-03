import 'package:flutter/material.dart';

import '../../../core/layout/app_shell.dart';
import '../../../core/theme/fixia_theme.dart';
import '../../../core/widgets/fixia_ui.dart';
import '../../quotations/presentation/quotation_card.dart' show formatDateTime;
import '../domain/service_evaluation.dart';
import '../domain/service_history_entry.dart';
import 'service_history_controller.dart';
import 'widgets/service_evaluations_view.dart';

/// Tono de la etiqueta según la etapa del servicio.
PillTone stageTone(HistoryStage stage) => switch (stage) {
      HistoryStage.active => PillTone.info,
      HistoryStage.finished => PillTone.warning,
      HistoryStage.closed => PillTone.success,
      HistoryStage.other => PillTone.neutral,
    };

/// «Mis servicios»: historial propio de servicios contratados, para cliente
/// y técnico (GC-449). Se distinguen activos, finalizados y cerrados; todo
/// sale de ms-services y ms-users, sin datos de ejemplo.
class ServiceHistoryPage extends StatefulWidget {
  const ServiceHistoryPage({
    super.key,
    required this.controller,
    required this.destination,
    required this.userId,
    required this.onOpen,
    required this.onSessionExpired,
  });

  final ServiceHistoryController controller;

  /// Sección del menú: la de cliente o la de técnico.
  final ShellDestination destination;

  /// Quien consulta, para distinguir la evaluación propia de la recibida.
  final String userId;

  /// Abre el detalle del servicio. Al volver, el historial se recarga para
  /// reflejar cambios (por ejemplo, un cierre confirmado).
  final Future<void> Function(ServiceHistoryEntry entry) onOpen;
  final VoidCallback onSessionExpired;

  static const emptyMessage =
      'Todavía no tienes servicios contratados. Cuando contrates o te contraten '
      'un servicio, aparecerá aquí.';

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  bool _sessionExpiryHandled = false;

  ServiceHistoryController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    // Siempre se consulta al abrir: el historial debe ser el persistido. El
    // controlador vive en la app, así que el filtro de una visita (o de otra
    // sesión) no se arrastra.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.setFilter(null);
      _controller.load();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (_controller.sessionExpired && !_sessionExpiryHandled) {
      _sessionExpiryHandled = true;
      widget.onSessionExpired();
    }
  }

  Future<void> _open(ServiceHistoryEntry entry) async {
    await widget.onOpen(entry);
    if (mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) => AppShell(
        destination: widget.destination,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Mis servicios',
                subtitle: 'Tus servicios contratados: lo acordado, su avance y '
                    'las evaluaciones.',
                actions: [
                  OutlinedButton.icon(
                    key: const ValueKey('service-history-refresh'),
                    onPressed:
                        _controller.status == ServiceHistoryStatus.loading
                            ? null
                            : _controller.load,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _content(context),
            ],
          ),
        ),
      );

  Widget _content(BuildContext context) {
    switch (_controller.status) {
      case ServiceHistoryStatus.idle:
      case ServiceHistoryStatus.loading:
        return const SectionLoading(key: ValueKey('service-history-loading'));
      case ServiceHistoryStatus.failure:
        return EmptyState(
          message: _controller.errorMessage ??
              ServiceHistoryController.unexpectedErrorMessage,
          icon: Icons.error_outline_rounded,
          action: TextButton(
            key: const ValueKey('service-history-retry'),
            onPressed: _controller.load,
            child: const Text('Reintentar'),
          ),
        );
      case ServiceHistoryStatus.ready:
        if (_controller.entries.isEmpty) {
          return const EmptyState(
            message: ServiceHistoryPage.emptyMessage,
            icon: Icons.history_rounded,
          );
        }
        return _list();
    }
  }

  Widget _list() {
    final all = _controller.entries;
    final shown = _controller.visibleEntries;
    int count(HistoryStage stage) => all.where((e) => e.stage == stage).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterPills<HistoryStage?>(
          keyPrefix: 'service-history-filter',
          selected: _controller.filter,
          onSelected: _controller.setFilter,
          options: [
            (null, 'Todos (${all.length})'),
            for (final stage in const [
              HistoryStage.active,
              HistoryStage.finished,
              HistoryStage.closed,
            ])
              (stage, '${stage.label} (${count(stage)})'),
          ],
        ),
        if (_controller.evaluationsUnavailable) ...[
          const SizedBox(height: 12),
          const NoticeBanner(
            key: ValueKey('service-history-evaluations-unavailable'),
            message: 'No pudimos consultar las evaluaciones. El resto del '
                'historial está actualizado.',
            tone: PillTone.neutral,
            icon: Icons.info_outline_rounded,
          ),
        ],
        const SizedBox(height: 16),
        if (shown.isEmpty)
          EmptyState(
            key: const ValueKey('service-history-filter-empty'),
            message: _controller.hasMore
                ? 'No hay servicios con este filtro entre los cargados. '
                    'Carga más para seguir buscando.'
                : 'No hay servicios con este filtro.',
            icon: Icons.filter_alt_off_outlined,
          )
        else
          _HistoryList(
            entries: shown,
            evaluationsOf: _controller.evaluationsOf,
            userId: widget.userId,
            onOpen: _open,
          ),
        if (_controller.loadMoreError != null) ...[
          const SizedBox(height: 12),
          Text(
            _controller.loadMoreError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FixiaColors.error),
          ),
        ],
        if (_controller.hasMore) ...[
          const SizedBox(height: 16),
          Center(
            child: _controller.isLoadingMore
                ? const CircularProgressIndicator(
                    key: ValueKey('service-history-loading-more'))
                : OutlinedButton(
                    key: const ValueKey('service-history-load-more'),
                    onPressed: _controller.loadMore,
                    child: const Text('Cargar más'),
                  ),
          ),
        ],
      ],
    );
  }
}

/// Tabla en pantallas anchas y tarjetas en celular, como «Mis solicitudes».
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.entries,
    required this.evaluationsOf,
    required this.userId,
    required this.onOpen,
  });

  final List<ServiceHistoryEntry> entries;
  final List<ServiceEvaluation> Function(String serviceRequestId) evaluationsOf;
  final String userId;
  final ValueChanged<ServiceHistoryEntry> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) return _table();
          return Column(
            children: [
              for (final entry in entries) ...[
                _card(entry),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      );

  Widget _table() {
    const header = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: FixiaColors.textSecondary,
      letterSpacing: 0.4,
    );
    return FixiaPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('SERVICIO', style: header)),
                Expanded(flex: 3, child: Text('ESTADO', style: header)),
                Expanded(flex: 2, child: Text('PRECIO', style: header)),
                Expanded(flex: 4, child: Text('AVANCE', style: header)),
                Expanded(flex: 2, child: Text('EVALUACIÓN', style: header)),
              ],
            ),
          ),
          for (final entry in entries)
            InkWell(
              key: ValueKey('service-history-${entry.contractId}'),
              onTap: () => onOpen(entry),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEEF2F7))),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _title(entry)),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _pill(entry),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(entry.contractedAmount.label),
                    ),
                    Expanded(flex: 4, child: _progress(entry)),
                    Expanded(flex: 2, child: _rating(entry)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(ServiceHistoryEntry entry) => InkWell(
        key: ValueKey('service-history-${entry.contractId}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => onOpen(entry),
        child: FixiaPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _title(entry)),
                  const SizedBox(width: 8),
                  _pill(entry),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Precio contratado: ${entry.contractedAmount.label}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              _progress(entry),
              const SizedBox(height: 6),
              _rating(entry),
            ],
          ),
        ),
      );

  Widget _title(ServiceHistoryEntry entry) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.category?.label ?? 'Servicio',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            entry.role.label,
            style: const TextStyle(
              fontSize: 12,
              color: FixiaColors.textSecondary,
            ),
          ),
        ],
      );

  Widget _pill(ServiceHistoryEntry entry) => StatusPill(
        key: ValueKey('service-history-stage-${entry.stage.name}'),
        label: entry.status?.label ?? 'Estado no disponible',
        tone: stageTone(entry.stage),
      );

  /// Fechas reales del ciclo; solo las que existen.
  Widget _progress(ServiceHistoryEntry entry) {
    final lines = <String>[
      'Contratado: ${formatDateTime(entry.contractedAt)}',
      if (entry.startedAt != null)
        'Iniciado: ${formatDateTime(entry.startedAt!)}',
      if (entry.finishedAt != null)
        'Terminado por el técnico: ${formatDateTime(entry.finishedAt!)}',
      if (entry.closedAt != null) 'Cerrado: ${formatDateTime(entry.closedAt!)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text(
            line,
            style: const TextStyle(
              fontSize: 12,
              color: FixiaColors.textSecondary,
            ),
          ),
      ],
    );
  }

  /// La evaluación recibida, si existe; nunca estrellas inventadas.
  Widget _rating(ServiceHistoryEntry entry) {
    final evaluations = evaluationsOf(entry.serviceRequestId);
    final received = evaluations.where((e) => e.isFor(userId)).toList();
    final given = evaluations.where((e) => e.isBy(userId)).toList();
    if (received.isEmpty && given.isEmpty) {
      return const Text(
        'Sin evaluaciones',
        style: TextStyle(fontSize: 12, color: FixiaColors.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (received.isNotEmpty)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Recibiste ', style: TextStyle(fontSize: 12)),
              RatingStars(rating: received.first.rating, size: 14),
            ],
          ),
        if (given.isNotEmpty)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Calificaste ', style: TextStyle(fontSize: 12)),
              RatingStars(rating: given.first.rating, size: 14),
            ],
          ),
      ],
    );
  }
}
