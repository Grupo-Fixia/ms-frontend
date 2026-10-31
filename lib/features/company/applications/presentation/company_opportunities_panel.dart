import 'package:flutter/material.dart';
import '../../../../core/theme/fixia_theme.dart';
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
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton(
            onPressed: _loading || _sending ? null : () => _load(refresh: true),
            child: const Text('Actualizar oportunidades')),
        if (_loading) const Text('Consultando oportunidades empresariales…'),
        if (_error != null) ...[
          Text(_error!),
          TextButton(
              onPressed: _loading || _sending
                  ? null
                  : () => _load(refresh: _items.isEmpty && _next == null),
              child: const Text('Reintentar oportunidades')),
        ],
        if (!_loading && _error == null && _items.isEmpty)
          Text(_next == null
              ? 'No hay oportunidades disponibles para tu empresa.'
              : 'Esta página no contiene oportunidades. Puedes seguir consultando.'),
        for (final item in _items)
          ListTile(
              key: ValueKey('company-opportunity-${item.request.id}'),
              selected: _selected?.request.id == item.request.id,
              title: Text(item.request.description),
              subtitle: Text('${item.request.zone}, ${item.request.city}\n'
                  '${item.budgetAmount == null ? 'Presupuesto no informado' : 'Presupuesto orientativo: ${item.budgetAmount} COP'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _sending || _loading
                  ? null
                  : () => setState(() => _selected = item)),
        if (_next != null)
          TextButton(
              onPressed: _loading || _sending ? null : () => _load(),
              child: const Text('Ver más oportunidades')),
        if (_selected != null) ...[
          const SizedBox(height: 24),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: FixiaColors.neutralBackground,
              borderRadius: BorderRadius.circular(FixiaRadii.card),
              border: Border.all(color: FixiaColors.secondary, width: 1.2),
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
                              'Solicitud seleccionada: ${_selected!.request.description}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: FixiaColors.primary)),
                        ]),
                  ),
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: CompanyApplicationPanel(
                          key: ValueKey(
                              '${widget.sessionKey}:${_selected!.request.id}'),
                          sessionKey: widget.sessionKey,
                          serviceRequestId: _selected!.request.id,
                          eligibleTechnicianIds:
                              _selected!.eligibleTechnicianIds,
                          techniciansController: widget.techniciansController,
                          applications: widget.applications,
                          onSessionExpired: widget.onSessionExpired,
                          onBusyChanged: (value) {
                            if (mounted) setState(() => _sending = value);
                            widget.onBusyChanged?.call(value);
                          })),
                ]),
          ),
        ],
      ]);
}
