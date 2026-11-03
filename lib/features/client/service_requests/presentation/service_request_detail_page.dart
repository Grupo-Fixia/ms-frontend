import 'package:flutter/material.dart';

import '../../../../core/domain/service_budget.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/theme/fixia_theme.dart';
import '../../../../core/widgets/fixia_ui.dart';
import '../domain/applicant.dart';
import '../domain/compatible_technician.dart';
import '../domain/service_request.dart';
import 'service_request_list.dart';

/// Detalle de una solicitud del cliente con sus postulantes reales (GC-426,
/// historia GC-403): compara precio y perfil público de cada propuesta y
/// selecciona un prestador contra ms-services.
///
/// Todo lo que muestra viene del servidor: tras seleccionar se vuelven a
/// consultar la solicitud y los postulantes, nunca se cambia el estado solo
/// en memoria. Seleccionar no es aceptar una cotización.
class ServiceRequestDetailPage extends StatefulWidget {
  const ServiceRequestDetailPage({
    super.key,
    required this.requestId,
    required this.get,
    required this.listApplicants,
    required this.selectProvider,
    this.extraSections,
    this.listCompatibleTechnicians,
  });

  /// Técnicos compatibles con la solicitud (GC-474), por páginas. Solo se
  /// consultan mientras la solicitud está publicada.
  final Future<CompatibleTechniciansPage> Function(String? cursor)?
      listCompatibleTechnicians;

  final String requestId;
  final Future<ServiceRequest> Function(String id) get;
  final Future<List<Applicant>> Function(String requestId) listApplicants;
  final Future<ServiceRequest> Function(String requestId, String applicationId)
      selectProvider;

  /// Secciones adicionales según el estado (cotización, contrato, cierre),
  /// que se construyen con la solicitud ya consultada. Reciben una función
  /// para volver a consultar todo después de una acción.
  final List<Widget> Function(
    BuildContext context,
    ServiceRequest request,
    Future<void> Function() reload,
  )? extraSections;

  @override
  State<ServiceRequestDetailPage> createState() =>
      _ServiceRequestDetailPageState();
}

class _ServiceRequestDetailPageState extends State<ServiceRequestDetailPage> {
  ServiceRequest? _request;
  Object? _requestError;
  List<Applicant>? _applicants;
  Object? _applicantsError;
  bool _loading = true;
  String? _selecting;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    ServiceRequest? request;
    Object? requestError;
    List<Applicant>? applicants;
    Object? applicantsError;
    try {
      request = await widget.get(widget.requestId);
    } catch (error) {
      requestError = error;
    }
    if (request != null) {
      try {
        applicants = await widget.listApplicants(widget.requestId);
      } catch (error) {
        applicantsError = error;
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _request = request;
      _requestError = requestError;
      _applicants = applicants;
      _applicantsError = applicantsError;
    });
  }

  Future<void> _select(Applicant applicant) async {
    if (_selecting != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar prestador'),
        content: Text(
          '¿Quieres elegir a ${applicant.displayName}'
          '${applicant.proposedPrice == null ? '' : ' por ${applicant.proposedPrice!.label}'}?\n\n'
          'Las demás postulaciones quedarán como no seleccionadas. '
          'Después el prestador te enviará una cotización formal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seleccionar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _selecting = applicant.id);
    String message;
    try {
      await widget.selectProvider(widget.requestId, applicant.id);
      message = 'Seleccionaste a ${_withoutFinalDot(applicant.displayName)}.';
    } catch (error) {
      message = '$error';
    }
    if (!mounted) return;
    setState(() => _selecting = null);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    // Lo que se ve después sale del servidor, haya funcionado o no.
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    Widget body;
    if (_loading && request == null) {
      body = const SectionLoading();
    } else if (request == null) {
      body = EmptyState(
        message: '$_requestError',
        icon: Icons.error_outline_rounded,
        action: OutlinedButton(
          onPressed: _reload,
          child: const Text('Reintentar'),
        ),
      );
    } else {
      final extra =
          widget.extraSections?.call(context, request, _reload) ?? const [];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: request.category.label,
            titleKey: const ValueKey('request-detail-title'),
            subtitle: request.description,
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: StatusPill(
                  label: request.status.label,
                  tone: toneFor(request.status),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('request-detail-refresh'),
                onPressed: _loading ? null : _reload,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          TwoColumns(
            sideWidth: 340,
            sideFirstWhenStacked: true,
            main: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...extra,
                if (extra.isNotEmpty) const SizedBox(height: 24),
                _applicantsSection(request),
              ],
            ),
            side: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RequestSummary(request: request),
                if (widget.listCompatibleTechnicians != null &&
                    request.status == ServiceRequestStatus.published) ...[
                  const SizedBox(height: 16),
                  CompatibleTechniciansPanel(
                    load: widget.listCompatibleTechnicians!,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return AppShell(
      destination: ShellDestination.clientRequests,
      subpage: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(label: 'Mis solicitudes'),
          body,
        ],
      ),
    );
  }

  Widget _applicantsSection(ServiceRequest request) {
    final error = _applicantsError;
    final applicants = _applicants;
    final canSelect = request.status == ServiceRequestStatus.published;
    final children = <Widget>[];
    if (error != null) {
      children.add(EmptyState(
        message: '$error',
        icon: Icons.error_outline_rounded,
        action: OutlinedButton(
          onPressed: _reload,
          child: const Text('Reintentar'),
        ),
      ));
    } else if (applicants == null) {
      children.add(const SizedBox.shrink());
    } else if (applicants.isEmpty) {
      children.add(EmptyState(
        icon: Icons.groups_outlined,
        message: canSelect
            ? 'Todavía no hay prestadores postulados. Te mostraremos sus propuestas aquí.'
            : 'Esta solicitud no tiene postulaciones.',
      ));
    } else {
      children.add(_PriceSummary(applicants: applicants));
      final cards = <Widget>[];
      for (final applicant in applicants) {
        cards.add(_ApplicantCard(
          applicant: applicant,
          budget: request.budget,
          selecting: _selecting == applicant.id,
          onSelect: canSelect &&
                  applicant.status == ApplicationStatus.applied &&
                  _selecting == null
              ? () => _select(applicant)
              : null,
        ));
      }
      children.add(ResponsiveGrid(minItemWidth: 300, children: cards));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: canSelect ? 'Compara las propuestas' : 'Postulantes',
        ),
        ...children,
      ],
    );
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final location = request.approximateLocation;
    final exact = request.exactLocation;
    return FixiaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos de la solicitud',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: FixiaColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.handyman_outlined,
            text: request.category.label,
          ),
          _InfoLine(
            icon: Icons.place_outlined,
            text: exact?.address ?? '${location.zone}, ${location.city}',
          ),
          _InfoLine(
            icon: Icons.event_outlined,
            text: 'Para el ${formatDate(request.expectedAt)}',
          ),
          _InfoLine(
            icon: Icons.payments_outlined,
            text:
                'Presupuesto orientativo: ${request.budget?.label ?? 'Presupuesto no informado'}',
          ),
          if (pendingActionFor(request.status) case final next?) ...[
            const SizedBox(height: 14),
            NoticeBanner(
              message: 'Siguiente paso: $next.',
              tone: PillTone.info,
              icon: Icons.flag_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({required this.applicants});

  final List<Applicant> applicants;

  @override
  Widget build(BuildContext context) {
    final prices = [
      for (final a in applicants)
        if (a.proposedPrice != null) a.proposedPrice!,
    ]..sort((a, b) => a.jsonAmount.compareTo(b.jsonAmount));
    final count = applicants.length;
    final text = StringBuffer(
      count == 1 ? '1 propuesta' : '$count propuestas',
    );
    if (prices.length == 1) {
      text.write(' · precio ${prices.first.label}');
    } else if (prices.length > 1) {
      text.write(' · de ${prices.first.label} a ${prices.last.label}');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toString(),
        style: const TextStyle(color: FixiaColors.textSecondary),
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.applicant,
    required this.budget,
    required this.selecting,
    required this.onSelect,
  });

  final Applicant applicant;
  final ServiceBudget? budget;
  final bool selecting;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final worker = applicant.workerProfile;
    final selected = applicant.status == ApplicationStatus.selected;
    final price = applicant.proposedPrice;
    final years = worker?.yearsOfExperience;
    return FixiaPanel(
      key: ValueKey('applicant-${applicant.id}'),
      highlight: selected ? FixiaColors.accent : null,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  applicant.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip(label: applicant.status.label, highlighted: selected),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip(label: applicant.providerType.label),
              if (worker?.verificationStatus != null)
                StatusChip(label: worker!.verificationStatus!.label),
            ],
          ),
          if (applicant.isCompany) ...[
            const SizedBox(height: 8),
            Text(
              'Técnico propuesto: ${worker?.displayName ?? 'no disponible'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if (applicant.provider == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Este prestador ya no está activo en Fixia.',
                style: TextStyle(color: FixiaColors.textSecondary),
              ),
            ),
          if (worker?.professionalDescription != null) ...[
            const SizedBox(height: 8),
            Text(worker!.professionalDescription!),
          ],
          const SizedBox(height: 8),
          if (years != null)
            _InfoLine(
              icon: Icons.workspace_premium_outlined,
              text: years == 1
                  ? '1 año de experiencia'
                  : '$years años de experiencia',
            ),
          if (worker != null && worker.categories.isNotEmpty)
            _InfoLine(
              icon: Icons.handyman_outlined,
              text: worker.categories.map((c) => c.label).join(', '),
            ),
          if (worker?.city != null)
            _InfoLine(icon: Icons.place_outlined, text: worker!.city!),
          const Divider(height: 24),
          const Text(
            'Precio propuesto',
            style: TextStyle(fontSize: 12, color: FixiaColors.textSecondary),
          ),
          Text(
            price?.label ?? 'Sin precio propuesto',
            style: TextStyle(
              fontSize: price == null ? 14 : 18,
              fontWeight: FontWeight.w700,
              color: price == null
                  ? FixiaColors.textSecondary
                  : FixiaColors.secondary,
            ),
          ),
          if (onSelect != null || selecting) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSelect,
                child: selecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Seleccionar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Etiqueta de estado compacta.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: highlighted
              ? FixiaColors.accent.withOpacity(0.15)
              : FixiaColors.supportBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: highlighted ? const Color(0xFF00745F) : FixiaColors.primary,
          ),
        ),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: FixiaColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: FixiaColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}

/// «Carlos G.» → «Carlos G», para no terminar la frase con dos puntos.
String _withoutFinalDot(String text) =>
    text.endsWith('.') ? text.substring(0, text.length - 1) : text;

/// Fecha corta en español (dd/mm/aaaa), en hora local.
String formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// «Técnicos que pueden atenderte» (GC-474): los que ofrecen la categoría,
/// atienden la ciudad y tienen horario a la hora pedida. Si matching no
/// responde lo dice con opción de reintentar, nunca como lista vacía.
class CompatibleTechniciansPanel extends StatefulWidget {
  const CompatibleTechniciansPanel({super.key, required this.load});

  final Future<CompatibleTechniciansPage> Function(String? cursor) load;

  /// Páginas vacías seguidas que se piden solas antes de detenerse.
  static const maxEmptyPages = 3;

  @override
  State<CompatibleTechniciansPanel> createState() =>
      _CompatibleTechniciansPanelState();
}

class _CompatibleTechniciansPanelState
    extends State<CompatibleTechniciansPanel> {
  final _items = <CompatibleTechnician>[];
  String? _cursor;
  bool _done = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var empty = 0;
      do {
        final page = await widget.load(_cursor);
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = !page.hasMore;
        empty = page.items.isEmpty ? empty + 1 : 0;
        // Una página vacía con cursor no significa que no haya más.
      } while (!_done &&
          empty > 0 &&
          empty < CompatibleTechniciansPanel.maxEmptyPages);
    } catch (error) {
      _error = '$error';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FixiaPanel(
      key: const ValueKey('compatible-technicians'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Técnicos que pueden atenderte',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: FixiaColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ofrecen este servicio, atienden tu ciudad y tienen horario a la hora que pediste. Pueden postularse a tu solicitud.',
            style: TextStyle(fontSize: 12, color: FixiaColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final t in _items) _CompatibleTile(technician: t),
          if (_items.isEmpty && _done && _error == null)
            const Text(
              'Por ahora ningún técnico cumple las condiciones. Tu solicitud sigue publicada y te avisaremos cuando alguien se postule.',
              key: ValueKey('compatible-technicians-empty'),
              style: TextStyle(color: FixiaColors.textSecondary),
            ),
          if (_error != null) ...[
            Text(
              _error!,
              key: const ValueKey('compatible-technicians-error'),
              style: const TextStyle(color: FixiaColors.textSecondary),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('compatible-technicians-retry'),
                onPressed: _more,
                child: const Text('Reintentar'),
              ),
            ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_done && _error == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('compatible-technicians-more'),
                onPressed: _more,
                child: const Text('Ver más técnicos'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompatibleTile extends StatelessWidget {
  const _CompatibleTile({required this.technician});

  final CompatibleTechnician technician;

  @override
  Widget build(BuildContext context) {
    final t = technician;
    final details = [
      if (t.categories.isNotEmpty) t.categories.map((c) => c.label).join(', '),
      if (t.city != null) t.city!,
    ].join(' · ');
    final initials = t.displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Padding(
      key: ValueKey('compatible-technician-${t.userId}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: FixiaColors.supportBackground,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FixiaColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 12,
                      color: FixiaColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
