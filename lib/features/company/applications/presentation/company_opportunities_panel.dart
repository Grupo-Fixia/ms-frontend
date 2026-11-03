import 'package:flutter/material.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../../../technician/applications/domain/application_exceptions.dart';
import '../application/company_repositories.dart';
import '../../technicians/presentation/company_technicians_controller.dart';
import '../domain/company_opportunity.dart';
import 'company_application_panel.dart';

class CompanyOpportunitiesPanel extends StatefulWidget {
  const CompanyOpportunitiesPanel(
      {super.key,
      required this.sessionKey,
      required this.opportunities,
      required this.techniciansController,
      required this.applications,
      this.onBusyChanged,
      required this.onSessionExpired});
  final String sessionKey;
  final CompanyOpportunitiesRepository opportunities;
  final CompanyTechniciansController techniciansController;
  final CompanyApplicationRepository applications;
  final VoidCallback onSessionExpired;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<CompanyOpportunitiesPanel> createState() =>
      _CompanyOpportunitiesPanelState();
}

class _CompanyOpportunitiesPanelState extends State<CompanyOpportunitiesPanel> {
  final _items = <CompanyOpportunity>[];
  final _seenCursors = <String>{};
  CompanyOpportunity? _selected;
  String? _next;
  String? _error;
  bool _loading = false;
  bool _sending = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  @override
  void didUpdateWidget(covariant CompanyOpportunitiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionKey != oldWidget.sessionKey ||
        widget.opportunities != oldWidget.opportunities ||
        widget.applications != oldWidget.applications ||
        widget.techniciansController != oldWidget.techniciansController) {
      _revision++;
      _sending = false;
      _load(refresh: true);
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_sending || (_loading && !refresh)) return;
    if (!refresh && _next == null) return;
    final revision = ++_revision;
    final cursor = refresh ? null : _next;
    setState(() {
      _loading = true;
      _error = null;
      if (refresh) {
        _items.clear();
        _selected = null;
        _next = null;
        _seenCursors.clear();
      }
    });
    try {
      if (widget.sessionKey.trim().isEmpty) {
        throw const ApplicationFailure(
            'Se requiere una sesión empresarial activa.');
      }
      final page =
          await widget.opportunities.fetchPage(limit: 20, cursor: cursor);
      if (!mounted || revision != _revision) return;
      if ((page.nextCursor != null &&
              (_seenCursors.contains(page.nextCursor) ||
                  page.nextCursor == cursor)) ||
          page.items.any((item) =>
              _items.any((old) => old.request.id == item.request.id))) {
        throw const ApplicationFailure(
            'La lista de oportunidades cambió. Actualiza la lista.');
      }
      setState(() {
        if (cursor != null) _seenCursors.add(cursor);
        _items.addAll(page.items);
        _next = page.nextCursor;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      if (error is ApplicationFailure && error.isSessionExpired) {
        widget.onSessionExpired();
      }
      if (mounted) {
        setState(() => _error = error is ApplicationFailure
            ? error.message
            : 'No pudimos cargar las oportunidades. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed:
                _loading || _sending ? null : () => _load(refresh: true),
            child: const Text('Actualizar oportunidades'),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Consultando oportunidades empresariales…'),
        ],
        if (_error != null)
          EmptyState(
            icon: Icons.error_outline_rounded,
            message: _error!,
            action: TextButton(
              onPressed: _loading || _sending
                  ? null
                  : () => _load(refresh: _items.isEmpty && _next == null),
              child: const Text('Reintentar oportunidades'),
            ),
          ),
        if (!_loading && _error == null && _items.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            message: _next == null
                ? 'No hay oportunidades disponibles para tu empresa.'
                : 'Esta página no contiene oportunidades. Puedes seguir consultando.',
          ),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OpportunityTile(
              key: ValueKey('company-opportunity-${item.request.id}'),
              item: item,
              selected: _selected?.request.id == item.request.id,
              onTap: _sending || _loading
                  ? null
                  : () => setState(() => _selected = item),
            ),
          ),
        if (_next != null)
          TextButton(
              onPressed: _loading || _sending ? null : () => _load(),
              child: const Text('Ver más oportunidades')),
      ],
    );
    final selected = _selected;
    final detail = selected == null
        ? const EmptyState(
            icon: Icons.touch_app_outlined,
            message:
                'Elige una oportunidad para postular a uno de tus técnicos.',
          )
        : Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: FixiaColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FixiaColors.secondary, width: 1.5),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: FixiaColors.supportBackground,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.assignment_outlined,
                                color: FixiaColors.primary, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('Tu postulación',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            color: FixiaColors.primary,
                                            fontWeight: FontWeight.w700))),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                              'Solicitud seleccionada: ${selected.request.description}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: FixiaColors.primary)),
                        ]),
                  ),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: CompanyApplicationPanel(
                          key: ValueKey(
                              '${widget.sessionKey}:${selected.request.id}'),
                          sessionKey: widget.sessionKey,
                          serviceRequestId: selected.request.id,
                          eligibleTechnicianIds:
                              selected.eligibleTechnicianIds,
                          techniciansController: widget.techniciansController,
                          applications: widget.applications,
                          onSessionExpired: widget.onSessionExpired,
                          onBusyChanged: (value) {
                            if (mounted) setState(() => _sending = value);
                            widget.onBusyChanged?.call(value);
                          })),
                ]),
          );
    // En computador: lista a la izquierda y la postulación a la derecha.
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 900) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: list),
            const SizedBox(width: 24),
            SizedBox(width: 420, child: detail),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          list,
          if (selected != null) ...[const SizedBox(height: 24), detail],
        ],
      );
    });
  }
}

class _OpportunityTile extends StatelessWidget {
  const _OpportunityTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CompanyOpportunity item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? FixiaColors.supportBackground : FixiaColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    selected ? FixiaColors.secondary : const Color(0xFFE3EAF4),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.request.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.request.zone}, ${item.request.city}\n'
                        '${item.budgetAmount == null ? 'Presupuesto no informado' : 'Presupuesto orientativo: ${item.budgetAmount} COP'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: FixiaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: FixiaColors.textSecondary),
              ],
            ),
          ),
        ),
      );
}
